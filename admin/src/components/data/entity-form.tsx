"use client";

import { useMemo, useState } from "react";
import { keepPreviousData, useQuery } from "@tanstack/react-query";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AlertCircle, ExternalLink, Info, LoaderCircle, X } from "lucide-react";

import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { useDialogFocus } from "@/hooks/use-dialog-focus";
import {
  fetchForeignRows,
  foreignRowLabel,
  humanizeIdentifier,
} from "@/lib/admin-data";
import type {
  ColumnMetadata,
  EntityDefinition,
  RowData,
  TableMetadata,
} from "@/lib/admin-types";
import { ENTITY_BY_NAME } from "@/lib/entity-registry";

import styles from "./entity.module.css";

type FormMode = "create" | "edit";

interface EntityFormProps {
  client: SupabaseClient;
  entity: EntityDefinition;
  metadata: TableMetadata;
  mode: FormMode;
  initial?: RowData;
  busy?: boolean;
  onClose: () => void;
  onSubmit: (values: RowData) => Promise<void>;
}

const MANAGED_COLUMNS = new Set(["created_at", "updated_at", "deleted_at"]);
const DHAKA_UTC_OFFSET = "+06:00";
const DHAKA_OFFSET_MILLISECONDS = 6 * 60 * 60 * 1000;
const LONG_TEXT_COLUMNS = new Set([
  "body",
  "body_bn",
  "description",
  "description_bn",
  "note",
  "reason",
  "message",
  "metadata",
  "old_data",
  "new_data",
]);

function isTimestamp(column: ColumnMetadata): boolean {
  return column.data_type.includes("timestamp") || column.base_type.includes("timestamp");
}

function isDate(column: ColumnMetadata): boolean {
  return column.data_type === "date" || column.base_type === "date";
}

function isTime(column: ColumnMetadata): boolean {
  return (
    !isTimestamp(column) &&
    (column.data_type.startsWith("time") || column.base_type.startsWith("time"))
  );
}

function isNumeric(column: ColumnMetadata): boolean {
  const type = `${column.data_type} ${column.base_type}`;
  return /(smallint|integer|bigint|numeric|decimal|real|double)/.test(type);
}

function isJson(column: ColumnMetadata): boolean {
  return column.data_type.includes("json") || column.base_type.includes("json");
}

function inputValue(column: ColumnMetadata, value: unknown): string | boolean {
  if (column.base_type === "bool" || column.data_type === "boolean") {
    if (value === null || value === undefined) {
      const defaultValue = column.default?.trim().toLowerCase();
      if (defaultValue === "true" || defaultValue === "'true'::boolean") return true;
      if (defaultValue === "false" || defaultValue === "'false'::boolean") return false;
    }
    return Boolean(value);
  }
  if (value === null || value === undefined) return "";
  if (isJson(column)) return JSON.stringify(value, null, 2);
  if (isTimestamp(column)) {
    const date = new Date(String(value));
    if (Number.isNaN(date.valueOf())) return String(value);
    const dhakaDate = new Date(date.valueOf() + DHAKA_OFFSET_MILLISECONDS);
    return dhakaDate.toISOString().slice(0, 23);
  }
  return String(value);
}

function parsedValue(
  column: ColumnMetadata,
  value: string | boolean,
): unknown {
  if (column.base_type === "bool" || column.data_type === "boolean") {
    return Boolean(value);
  }

  const text = String(value).trim();
  if (!text) return column.nullable ? null : "";
  if (isJson(column)) return JSON.parse(text) as unknown;
  if (isTimestamp(column)) return new Date(`${text}${DHAKA_UTC_OFFSET}`).toISOString();
  // Keep numeric input as a string. Postgres casts it safely and this avoids
  // losing precision for bigint values in JavaScript.
  if (isNumeric(column)) return text;
  return text;
}

function editableColumns(
  entity: EntityDefinition,
  metadata: TableMetadata,
  mode: FormMode,
): ColumnMetadata[] {
  const alwaysLocked = new Set(entity.lockedColumns ?? []);
  const editLocked = new Set(entity.updateLockedColumns ?? []);

  return metadata.columns.filter((column) => {
    if (column.identity || column.generated || MANAGED_COLUMNS.has(column.name)) return false;
    if (alwaysLocked.has(column.name)) return false;
    if (mode === "edit" && (column.primary_key || editLocked.has(column.name))) return false;
    if (mode === "create" && column.primary_key && column.default) return false;
    return true;
  });
}

function ForeignKeyField({
  client,
  column,
  value,
  onChange,
}: {
  client: SupabaseClient;
  column: ColumnMetadata;
  value: string;
  onChange: (value: string) => void;
}) {
  const foreign = column.foreign_key;
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebouncedValue(search, 250);
  const foreignEntity = foreign ? ENTITY_BY_NAME.get(foreign.table) : undefined;
  const { data = [], isLoading, error } = useQuery({
    queryKey: [
      "foreign-options",
      foreign?.table,
      foreign?.column,
      value,
      debouncedSearch,
    ],
    queryFn: () =>
      fetchForeignRows(client, foreign!.table, {
        currentColumn: foreign!.column,
        currentValue: value,
        search: debouncedSearch,
        searchColumns: foreignEntity?.searchColumns ?? [],
      }),
    enabled: Boolean(foreign),
    placeholderData: keepPreviousData,
    staleTime: 5 * 60 * 1000,
  });

  if (!foreign) return null;

  return (
    <>
      <input
        aria-label={`Search ${humanizeIdentifier(foreign.table)} options`}
        className={`${styles.formControl} ${styles.foreignSearch}`}
        onChange={(event) => setSearch(event.target.value)}
        placeholder={
          foreignEntity?.searchColumns.length
            ? `Search ${humanizeIdentifier(foreign.table).toLowerCase()}...`
            : "Paste an exact ID to find it"
        }
        type="search"
        value={search}
      />
      <select
        className={styles.formControl}
        disabled={isLoading}
        onChange={(event) => onChange(event.target.value)}
        required={!column.nullable && !column.default}
        value={value}
      >
        <option value="">
          {isLoading ? "Loading options…" : column.nullable ? "None" : "Select an option"}
        </option>
        {data.map((row) => {
          const optionValue = String(row[foreign.column] ?? "");
          return (
            <option key={optionValue} value={optionValue}>
              {foreignRowLabel(row)}
            </option>
          );
        })}
      </select>
      {error ? (
        <span className={styles.fieldHintError}>
          Options unavailable. Check the search value and your database access.
        </span>
      ) : null}
    </>
  );
}

function Field({
  client,
  column,
  value,
  onChange,
}: {
  client: SupabaseClient;
  column: ColumnMetadata;
  value: string | boolean;
  onChange: (value: string | boolean) => void;
}) {
  const required = !column.nullable && !column.default;

  if (column.foreign_key) {
    return (
      <ForeignKeyField
        client={client}
        column={column}
        onChange={onChange}
        value={String(value)}
      />
    );
  }

  if (column.enum_values?.length) {
    return (
      <select
        className={styles.formControl}
        onChange={(event) => onChange(event.target.value)}
        required={required}
        value={String(value)}
      >
        {column.nullable ? <option value="">None</option> : null}
        {!value && required ? <option value="">Select an option</option> : null}
        {column.enum_values.map((option) => (
          <option key={option} value={option}>
            {humanizeIdentifier(option)}
          </option>
        ))}
      </select>
    );
  }

  if (column.base_type === "bool" || column.data_type === "boolean") {
    return (
      <label className={styles.switchField}>
        <input
          checked={Boolean(value)}
          onChange={(event) => onChange(event.target.checked)}
          type="checkbox"
        />
        <span>{value ? "Enabled" : "Disabled"}</span>
      </label>
    );
  }

  if (isJson(column) || LONG_TEXT_COLUMNS.has(column.name)) {
    return (
      <textarea
        className={`${styles.formControl} ${styles.textarea}`}
        onChange={(event) => onChange(event.target.value)}
        placeholder={isJson(column) ? '{\n  "key": "value"\n}' : undefined}
        required={required}
        rows={isJson(column) ? 7 : 4}
        value={String(value)}
      />
    );
  }

  const type = isTimestamp(column)
    ? "datetime-local"
    : isDate(column)
      ? "date"
      : isTime(column)
        ? "time"
        : isNumeric(column)
          ? "number"
          : column.name.includes("email")
            ? "email"
            : column.name.includes("url") || column.name.includes("link")
              ? "url"
              : "text";

  return (
    <input
      className={styles.formControl}
      onChange={(event) => onChange(event.target.value)}
      required={required}
      step={isTimestamp(column) ? "0.001" : isNumeric(column) ? "any" : undefined}
      type={type}
      value={String(value)}
    />
  );
}

export function EntityForm({
  client,
  entity,
  metadata,
  mode,
  initial,
  busy = false,
  onClose,
  onSubmit,
}: EntityFormProps) {
  const columns = useMemo(
    () => editableColumns(entity, metadata, mode),
    [entity, metadata, mode],
  );
  const [values, setValues] = useState<Record<string, string | boolean>>(() =>
    Object.fromEntries(
      columns.map((column) => [column.name, inputValue(column, initial?.[column.name])]),
    ),
  );
  const [touchedColumns, setTouchedColumns] = useState<Set<string>>(
    () => new Set(),
  );
  const [formError, setFormError] = useState<string | null>(null);
  const dialogRef = useDialogFocus<HTMLElement>(
    true,
    busy ? undefined : onClose,
  );

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setFormError(null);

    try {
      if (mode === "edit" && touchedColumns.size === 0) {
        setFormError("Change at least one field before saving.");
        return;
      }

      const payload: RowData = {};
      for (const column of columns) {
        if (mode === "edit" && !touchedColumns.has(column.name)) continue;

        const raw = values[column.name];
        if (
          mode === "create" &&
          column.default &&
          (!touchedColumns.has(column.name) || raw === "" || raw === undefined)
        ) {
          continue;
        }
        payload[column.name] = parsedValue(column, raw ?? "");
      }
      await onSubmit(payload);
    } catch (error) {
      setFormError(error instanceof Error ? error.message : "The record could not be saved.");
    }
  }

  return (
    <div className={styles.drawerBackdrop} role="presentation" onMouseDown={onClose}>
      <aside
        aria-labelledby="entity-form-title"
        aria-modal="true"
        className={styles.drawer}
        onMouseDown={(event) => event.stopPropagation()}
        ref={dialogRef}
        role="dialog"
        tabIndex={-1}
      >
        <header className={styles.drawerHeader}>
          <div>
            <span className={styles.eyebrow}>{mode === "create" ? "New record" : "Edit record"}</span>
            <h2 id="entity-form-title">
              {mode === "create" ? `Create ${entity.singular}` : `Edit ${entity.singular}`}
            </h2>
          </div>
          <button
            aria-label="Close"
            className={styles.iconButton}
            data-dialog-initial-focus
            onClick={onClose}
          >
            <X size={19} />
          </button>
        </header>

        <div className={styles.formNotice}>
          <Info size={17} />
          <span>
            Database defaults, generated IDs, timestamps, and protected fields are handled
            automatically.
          </span>
        </div>

        <form className={styles.entityForm} onSubmit={submit}>
          <div className={styles.formFields}>
            {columns.map((column) => (
              <label className={styles.field} key={column.name}>
                <span className={styles.fieldLabel}>
                  {humanizeIdentifier(column.name)}
                  {!column.nullable && !column.default ? <b aria-label="required">*</b> : null}
                </span>
                <Field
                  client={client}
                  column={column}
                  onChange={(value) => {
                    setValues((current) => ({ ...current, [column.name]: value }));
                    setTouchedColumns((current) => {
                      const next = new Set(current);
                      next.add(column.name);
                      return next;
                    });
                  }}
                  value={values[column.name] ?? ""}
                />
                <span className={styles.fieldMeta}>
                  {column.data_type}
                  {column.foreign_key ? (
                    <>
                      {" · references "}
                      <span>
                        {column.foreign_key.table}.{column.foreign_key.column}
                      </span>
                    </>
                  ) : null}
                  {column.comment ? ` · ${column.comment}` : null}
                </span>
              </label>
            ))}
          </div>

          {columns.length === 0 ? (
            <div className={styles.emptyInline}>
              <AlertCircle size={20} />
              No editable fields were found for this relation.
            </div>
          ) : null}

          {formError ? (
            <div className={styles.formError} role="alert">
              <AlertCircle size={18} />
              <span>{formError}</span>
            </div>
          ) : null}

          <footer className={styles.drawerFooter}>
            <a
              className={styles.docsLink}
              href="https://supabase.com/docs/guides/database/tables"
              rel="noreferrer"
              target="_blank"
            >
              Database rules <ExternalLink size={14} />
            </a>
            <div>
              <button className={styles.secondaryButton} disabled={busy} onClick={onClose} type="button">
                Cancel
              </button>
              <button
                className={styles.primaryButton}
                disabled={
                  busy ||
                  columns.length === 0 ||
                  (mode === "edit" && touchedColumns.size === 0)
                }
                type="submit"
              >
                {busy ? <LoaderCircle className={styles.spin} size={17} /> : null}
                {busy ? "Saving…" : mode === "create" ? "Create record" : "Save changes"}
              </button>
            </div>
          </footer>
        </form>
      </aside>
    </div>
  );
}
