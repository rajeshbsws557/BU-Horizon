import type { SupabaseClient } from "@supabase/supabase-js";

import type {
  ColumnMetadata,
  EntityDefinition,
  Json,
  PagedRows,
  RowData,
  SchemaCatalogResponse,
  SortDirection,
  TableMetadata,
} from "@/lib/admin-types";

export interface RowQueryOptions {
  page: number;
  pageSize: number;
  search: string;
  sort: string;
  direction: SortDirection;
  includeArchived: boolean;
}

const COMPOSITE_PRIMARY_KEYS: Record<string, string[]> = {
  bus_route_favorites: ["profile_id", "route_id"],
};

function catalogPayload(value: unknown): SchemaCatalogResponse {
  if (!value || typeof value !== "object") {
    throw new Error("The schema catalog returned an invalid response.");
  }

  const candidate = value as Partial<SchemaCatalogResponse>;
  if (!Array.isArray(candidate.relations)) {
    throw new Error(
      "The admin schema catalog is unavailable. Apply migration 20260721000018 first.",
    );
  }

  return {
    generated_at: candidate.generated_at ?? new Date().toISOString(),
    relations: candidate.relations,
  };
}

export async function fetchSchemaCatalog(
  client: SupabaseClient,
): Promise<SchemaCatalogResponse> {
  const { data, error } = await client.rpc("admin_schema_catalog");
  if (error) throw error;
  return catalogPayload(data);
}

// PostgREST's `or` syntax is a small expression language. Search values are
// intentionally reduced to plain text before interpolation.
function safeSearchValue(value: string): string {
  return value
    .replace(/[(),.%*'"\\]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120);
}

export async function fetchRows(
  client: SupabaseClient,
  entity: EntityDefinition,
  options: RowQueryOptions,
): Promise<PagedRows> {
  const start = options.page * options.pageSize;
  const end = start + options.pageSize - 1;
  let query = client.from(entity.name).select("*", { count: "exact" });

  if (entity.softDelete && !options.includeArchived) {
    query = query.is("deleted_at", null);
  }

  const search = safeSearchValue(options.search);
  if (search && entity.searchColumns.length > 0) {
    query = query.or(
      entity.searchColumns
        .map((column) => `${column}.ilike.%${search}%`)
        .join(","),
    );
  }

  query = query
    .order(options.sort, {
      ascending: options.direction === "asc",
      nullsFirst: false,
    })
    .range(start, end);

  const { data, error, count } = await query;
  if (error) throw error;

  return {
    rows: (data ?? []) as RowData[],
    count: count ?? 0,
  };
}

export function primaryKeyColumns(metadata: TableMetadata): string[] {
  const fromCatalog = metadata.columns
    .filter((column) => column.primary_key)
    .map((column) => column.name);

  if (fromCatalog.length > 0) return fromCatalog;
  return COMPOSITE_PRIMARY_KEYS[metadata.name] ?? [];
}

function applyPrimaryKeyFilter<T>(
  query: T,
  metadata: TableMetadata,
  row: RowData,
): T {
  const keys = primaryKeyColumns(metadata);
  if (keys.length === 0) {
    throw new Error(`No primary key was found for ${metadata.name}.`);
  }

  let filtered: T = query;
  for (const key of keys) {
    if (row[key] === undefined || row[key] === null) {
      throw new Error(`The selected row has no ${key} primary-key value.`);
    }
    filtered = (
      filtered as unknown as {
        eq: (column: string, value: string | number | boolean) => T;
      }
    ).eq(key, row[key] as string | number | boolean);
  }
  return filtered;
}

export async function insertRow(
  client: SupabaseClient,
  table: string,
  values: RowData,
): Promise<RowData> {
  const { data, error } = await client
    .from(table)
    .insert(values)
    .select("*")
    .single();
  if (error) throw error;
  return data as RowData;
}

export async function updateRow(
  client: SupabaseClient,
  metadata: TableMetadata,
  original: RowData,
  values: RowData,
): Promise<RowData> {
  const mutation = client.from(metadata.name).update(values);
  const filtered = applyPrimaryKeyFilter(mutation, metadata, original);
  const { data, error } = await filtered.select("*").single();
  if (error) throw error;
  return data as RowData;
}

export async function deleteRow(
  client: SupabaseClient,
  metadata: TableMetadata,
  row: RowData,
): Promise<void> {
  const mutation = client.from(metadata.name).delete();
  const filtered = applyPrimaryKeyFilter(mutation, metadata, row);
  const { error } = await filtered;
  if (error) throw error;
}

export async function setArchived(
  client: SupabaseClient,
  metadata: TableMetadata,
  row: RowData,
  archived: boolean,
): Promise<void> {
  const mutation = client
    .from(metadata.name)
    .update({ deleted_at: archived ? new Date().toISOString() : null });
  const filtered = applyPrimaryKeyFilter(mutation, metadata, row);
  const { error } = await filtered;
  if (error) throw error;
}

export async function fetchForeignRows(
  client: SupabaseClient,
  table: string,
  options?: {
    currentColumn: string;
    currentValue: string;
    search: string;
    searchColumns: string[];
  },
): Promise<RowData[]> {
  const search = safeSearchValue(options?.search ?? "");
  let query = client.from(table).select("*");

  if (search) {
    if (options?.searchColumns.length) {
      query = query.or(
        options.searchColumns
          .map((column) => `${column}.ilike.%${search}%`)
          .join(","),
      );
    } else if (options?.currentColumn) {
      query = query.eq(options.currentColumn, search);
    }
  }

  const { data, error } = await query.limit(50);
  if (error) throw error;

  const rows = (data ?? []) as RowData[];
  const currentValue = options?.currentValue;
  const currentColumn = options?.currentColumn;
  if (
    !currentValue ||
    !currentColumn ||
    rows.some((row) => String(row[currentColumn] ?? "") === currentValue)
  ) {
    return rows;
  }

  const { data: current, error: currentError } = await client
    .from(table)
    .select("*")
    .eq(currentColumn, currentValue)
    .maybeSingle();
  if (currentError) throw currentError;
  return current ? [current as RowData, ...rows] : rows;
}

export function inferMetadata(
  entity: EntityDefinition,
  rows: RowData[],
): TableMetadata {
  const names = new Set<string>();
  for (const row of rows) {
    Object.keys(row).forEach((name) => names.add(name));
  }

  const columns: ColumnMetadata[] = [...names].map((name) => {
    const sample = rows.find((row) => row[name] !== null)?.[name];
    const dataType =
      typeof sample === "boolean"
        ? "boolean"
        : typeof sample === "number"
          ? "numeric"
          : typeof sample === "object"
            ? "jsonb"
            : "text";

    return {
      name,
      data_type: dataType,
      base_type: dataType,
      nullable: true,
      default: null,
      primary_key:
        name === "id" || COMPOSITE_PRIMARY_KEYS[entity.name]?.includes(name) === true,
      identity: false,
      generated: false,
      enum_values: null,
      foreign_key: null,
      comment: null,
    };
  });

  return {
    name: entity.name,
    kind: entity.readOnly ? "view" : "table",
    comment: entity.description,
    estimated_rows: rows.length,
    total_bytes: 0,
    columns,
  };
}

export function humanizeIdentifier(value: string): string {
  return value
    .replace(/_/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export function foreignRowLabel(row: RowData): string {
  const primary =
    row.full_name ??
    row.title ??
    row.name ??
    row.code ??
    row.session ??
    row.email ??
    row.id;
  const secondary =
    row.full_name && row.email
      ? row.email
      : row.code && row.title
        ? row.title
        : row.name && row.code
          ? row.code
          : null;

  return secondary ? `${String(primary)} · ${String(secondary)}` : String(primary ?? "Unknown");
}

function csvCell(value: unknown): string {
  if (value === null || value === undefined) return "";
  let text =
    typeof value === "object" ? JSON.stringify(value) : String(value);
  const formulaAfterWhitespace =
    /^[\s\u0000-\u001f\u007f\u200b-\u200d\ufeff]*[=+\-@]/u.test(text);
  const leadingControlCharacter = /^[\u0000-\u001f\u007f]/u.test(text);
  if (
    typeof value === "string" &&
    (formulaAfterWhitespace || leadingControlCharacter)
  ) {
    text = `'${text}`;
  }
  return `"${text.replace(/"/g, '""')}"`;
}

export function rowsToCsv(rows: RowData[], columns: string[]): string {
  const header = columns.map(csvCell).join(",");
  const lines = rows.map((row) =>
    columns.map((column) => csvCell(row[column])).join(","),
  );
  return `\uFEFF${[header, ...lines].join("\r\n")}`;
}

export function downloadText(
  contents: string,
  fileName: string,
  mimeType: string,
): void {
  const blob = new Blob([contents], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  URL.revokeObjectURL(url);
}

export function isJsonValue(value: unknown): value is Json {
  if (value === null) return true;
  if (["string", "number", "boolean"].includes(typeof value)) return true;
  if (Array.isArray(value)) return value.every(isJsonValue);
  if (typeof value === "object") {
    return Object.values(value as Record<string, unknown>).every(
      (entry) => entry === undefined || isJsonValue(entry),
    );
  }
  return false;
}
