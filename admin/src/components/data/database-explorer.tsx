"use client";

import { useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import {
  BookOpenCheck,
  Braces,
  Columns3,
  Database,
  Download,
  HardDrive,
  Layers3,
  Search,
  Table2,
} from "lucide-react";
import { toast } from "sonner";

import {
  downloadText,
  fetchSchemaCatalog,
  humanizeIdentifier,
} from "@/lib/admin-data";
import type {
  EntityDefinition,
  SchemaCatalogResponse,
  TableMetadata,
} from "@/lib/admin-types";
import {
  ENTITIES,
  ENTITY_BY_NAME,
  ENTITY_GROUPS,
} from "@/lib/entity-registry";
import { createBrowserClient } from "@/lib/supabase/client";

import { EntityTable } from "./entity-table";
import styles from "./workspace.module.css";

function formatBytes(bytes: number): string {
  if (!bytes) return "—";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value >= 10 || unit === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[unit]}`;
}

function dynamicDefinition(relation: TableMetadata): EntityDefinition {
  const textTypes = relation.columns
    .filter((column) => /text|char|citext/.test(`${column.data_type} ${column.base_type}`))
    .map((column) => column.name)
    .slice(0, 6);
  const primary = relation.columns.find((column) => column.primary_key)?.name;
  const dateColumn = relation.columns.find((column) => column.name === "created_at")?.name;
  return {
    name: relation.name,
    label: humanizeIdentifier(relation.name),
    singular: humanizeIdentifier(relation.name).replace(/s$/, "").toLowerCase(),
    group: "system",
    description: relation.comment ?? "Public database relation discovered from Supabase metadata.",
    searchColumns: textTypes,
    preferredColumns: relation.columns.slice(0, 8).map((column) => column.name),
    defaultSort: dateColumn ?? primary ?? relation.columns[0]?.name ?? "id",
    defaultDirection: dateColumn ? "desc" : "asc",
    // Newly discovered relations are visible immediately, but mutations are
    // opt-in through the reviewed registry rather than fail-open.
    readOnly: true,
  };
}

function catalogEntities(catalog?: SchemaCatalogResponse): EntityDefinition[] {
  if (!catalog) return ENTITIES;
  return catalog.relations.map(
    (relation) => ENTITY_BY_NAME.get(relation.name) ?? dynamicDefinition(relation),
  );
}

export function DatabaseExplorer() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const client = useMemo(() => createBrowserClient(), []);
  const [relationSearch, setRelationSearch] = useState("");
  const schemaQuery = useQuery({
    queryKey: ["admin-schema-catalog"],
    queryFn: () => fetchSchemaCatalog(client),
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });

  const entities = useMemo(
    () => catalogEntities(schemaQuery.data),
    [schemaQuery.data],
  );
  const requested = searchParams.get("table");
  const selected =
    entities.find((entity) => entity.name === requested) ??
    entities.find((entity) => entity.name === "profiles") ??
    entities[0];
  const selectedMetadata = schemaQuery.data?.relations.find(
    (relation) => relation.name === selected.name,
  );
  const filtered = entities.filter((entity) =>
    `${entity.label} ${entity.name} ${entity.description}`
      .toLowerCase()
      .includes(relationSearch.toLowerCase()),
  );
  const grouped = Object.entries(ENTITY_GROUPS)
    .map(([group, value]) => ({
      group,
      label: value.label,
      entities: filtered.filter((entity) => entity.group === group),
    }))
    .filter((group) => group.entities.length > 0);

  const totalBytes = schemaQuery.data?.relations.reduce(
    (sum, relation) => sum + relation.total_bytes,
    0,
  );
  const estimatedRows = schemaQuery.data?.relations.reduce(
    (sum, relation) => sum + relation.estimated_rows,
    0,
  );

  function selectRelation(table: string) {
    const params = new URLSearchParams(searchParams.toString());
    params.set("table", table);
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  }

  function exportSchema() {
    if (!schemaQuery.data) return;
    downloadText(
      JSON.stringify(schemaQuery.data, null, 2),
      `bu-horizon-schema-${new Date().toISOString().slice(0, 10)}.json`,
      "application/json",
    );
    toast.success("Schema catalog exported");
  }

  return (
    <div className={styles.workspace}>
      <header className={styles.pageHeader}>
        <div>
          <span className={styles.eyebrow}>Supabase · public schema</span>
          <h1>Database explorer</h1>
          <p>
            Inspect every public table and view with exact row pagination, relationship-aware
            forms, raw values, and CSV export.
          </p>
        </div>
        <button
          className={styles.exportSchemaButton}
          disabled={!schemaQuery.data}
          onClick={exportSchema}
          type="button"
        >
          <Download size={16} /> Export schema
        </button>
      </header>

      <div className={styles.databaseStats}>
        <div>
          <span className={styles.statIconBlue}><Layers3 size={19} /></span>
          <p>Relations</p>
          <strong>{schemaQuery.data?.relations.length ?? entities.length}</strong>
          <small>tables and views</small>
        </div>
        <div>
          <span className={styles.statIconGreen}><Table2 size={19} /></span>
          <p>Base tables</p>
          <strong>
            {schemaQuery.data?.relations.filter((relation) => !relation.kind.includes("view"))
              .length ?? 30}
          </strong>
          <small>RLS protected</small>
        </div>
        <div>
          <span className={styles.statIconPurple}><Database size={19} /></span>
          <p>Estimated rows</p>
          <strong>{estimatedRows?.toLocaleString() ?? "—"}</strong>
          <small>catalog estimate</small>
        </div>
        <div>
          <span className={styles.statIconGold}><HardDrive size={19} /></span>
          <p>Database size</p>
          <strong>{formatBytes(totalBytes ?? 0)}</strong>
          <small>public relations</small>
        </div>
      </div>

      <div className={styles.explorerLayout}>
        <aside className={styles.relationSidebar}>
          <header>
            <div>
              <strong>Data browser</strong>
              <span>{entities.length} relations</span>
            </div>
            <label>
              <Search size={15} />
              <input
                onChange={(event) => setRelationSearch(event.target.value)}
                placeholder="Find a table…"
                value={relationSearch}
              />
            </label>
          </header>
          <div className={styles.relationGroups}>
            {grouped.map((group) => (
              <section key={group.group}>
                <h2>{group.label}</h2>
                {group.entities.map((entity) => {
                  const relation = schemaQuery.data?.relations.find(
                    (candidate) => candidate.name === entity.name,
                  );
                  return (
                    <button
                      className={selected.name === entity.name ? styles.activeRelation : undefined}
                      key={entity.name}
                      onClick={() => selectRelation(entity.name)}
                      type="button"
                    >
                      <span>
                        {entity.readOnly ? <BookOpenCheck size={15} /> : <Table2 size={15} />}
                      </span>
                      <div>
                        <strong>{entity.label}</strong>
                        <small>{entity.name}</small>
                      </div>
                      {relation ? <b>{relation.estimated_rows.toLocaleString()}</b> : null}
                    </button>
                  );
                })}
              </section>
            ))}
          </div>
        </aside>

        <main className={styles.explorerMain}>
          <div className={styles.relationInfo}>
            <div>
              <span className={selected.readOnly ? styles.viewIcon : styles.tableIcon}>
                {selected.readOnly ? <Braces size={19} /> : <Table2 size={19} />}
              </span>
              <div>
                <span>{selectedMetadata?.kind.replace(/_/g, " ") ?? (selected.readOnly ? "view" : "table")}</span>
                <h2>public.{selected.name}</h2>
              </div>
            </div>
            <dl>
              <div>
                <dt><Columns3 size={14} /> Columns</dt>
                <dd>{selectedMetadata?.columns.length ?? "—"}</dd>
              </div>
              <div>
                <dt><Database size={14} /> Est. rows</dt>
                <dd>{selectedMetadata?.estimated_rows.toLocaleString() ?? "—"}</dd>
              </div>
              <div>
                <dt><HardDrive size={14} /> Size</dt>
                <dd>{formatBytes(selectedMetadata?.total_bytes ?? 0)}</dd>
              </div>
            </dl>
          </div>

          <EntityTable
            client={client}
            entity={selected}
            key={selected.name}
            metadata={selectedMetadata}
            schemaError={
              schemaQuery.error
                ? schemaQuery.error instanceof Error
                  ? schemaQuery.error.message
                  : "Schema catalog RPC failed."
                : null
            }
          />
        </main>
      </div>
    </div>
  );
}
