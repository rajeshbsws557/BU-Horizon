"use client";

import { useMemo } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import {
  BookOpenCheck,
  Boxes,
  CircleAlert,
  Database,
  Layers3,
} from "lucide-react";

import { fetchSchemaCatalog } from "@/lib/admin-data";
import type { EntityGroupId } from "@/lib/admin-types";
import {
  ENTITIES,
  ENTITY_GROUPS,
  entitiesForGroup,
} from "@/lib/entity-registry";
import { createBrowserClient } from "@/lib/supabase/client";

import { EntityTable } from "./entity-table";
import styles from "./workspace.module.css";

interface SectionWorkspaceProps {
  title: string;
  description: string;
  eyebrow: string;
  groups?: EntityGroupId[];
  entityNames?: string[];
  defaultEntity?: string;
}

export function SectionWorkspace({
  title,
  description,
  eyebrow,
  groups,
  entityNames,
  defaultEntity,
}: SectionWorkspaceProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const client = useMemo(() => createBrowserClient(), []);
  const entities = useMemo(() => {
    if (entityNames) {
      const names = new Set(entityNames);
      return ENTITIES.filter((entity) => names.has(entity.name));
    }
    if (groups) {
      const groupSet = new Set(groups);
      return ENTITIES.filter((entity) => groupSet.has(entity.group));
    }
    return ENTITIES;
  }, [entityNames, groups]);

  const requestedTable = searchParams.get("table");
  const selected =
    entities.find((entity) => entity.name === requestedTable) ??
    entities.find((entity) => entity.name === defaultEntity) ??
    entities[0];

  const schemaQuery = useQuery({
    queryKey: ["admin-schema-catalog"],
    queryFn: () => fetchSchemaCatalog(client),
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });

  const metadata = schemaQuery.data?.relations.find(
    (relation) => relation.name === selected?.name,
  );

  function selectTable(table: string) {
    const params = new URLSearchParams(searchParams.toString());
    params.set("table", table);
    router.replace(`${pathname}?${params.toString()}`, { scroll: false });
  }

  if (!selected) {
    return (
      <div className={styles.emptyWorkspace}>
        <CircleAlert size={28} />
        <h1>No data modules configured</h1>
        <p>This section does not have any registered database relations.</p>
      </div>
    );
  }

  return (
    <div className={styles.workspace}>
      <header className={styles.pageHeader}>
        <div>
          <span className={styles.eyebrow}>{eyebrow}</span>
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
        <div className={styles.headerSummary}>
          <div>
            <Layers3 size={18} />
            <span><b>{entities.length}</b> data modules</span>
          </div>
          <div>
            <Database size={18} />
            <span>
              <b>
                {schemaQuery.data
                  ? entities
                      .map(
                        (entity) =>
                          schemaQuery.data?.relations.find(
                            (relation) => relation.name === entity.name,
                          )?.estimated_rows ?? 0,
                      )
                      .reduce((sum, count) => sum + count, 0)
                      .toLocaleString()
                  : "—"}
              </b>{" "}
              estimated rows
            </span>
          </div>
        </div>
      </header>

      <nav aria-label={`${title} data modules`} className={styles.entityTabs}>
        {entities.map((entity) => (
          <button
            aria-current={entity.name === selected.name ? "page" : undefined}
            className={entity.name === selected.name ? styles.activeTab : undefined}
            key={entity.name}
            onClick={() => selectTable(entity.name)}
            type="button"
          >
            <span>{entity.readOnly ? <BookOpenCheck size={15} /> : <Boxes size={15} />}</span>
            {entity.label}
            {entity.readOnly ? <small>View</small> : null}
          </button>
        ))}
      </nav>

      <EntityTable
        client={client}
        entity={selected}
        key={selected.name}
        metadata={metadata}
        schemaError={
          schemaQuery.error
            ? schemaQuery.error instanceof Error
              ? schemaQuery.error.message
              : "Schema catalog RPC failed."
            : null
        }
      />
    </div>
  );
}

export function GroupDescription({ group }: { group: EntityGroupId }) {
  return (
    <span title={ENTITY_GROUPS[group].description}>
      {ENTITY_GROUPS[group].label} · {entitiesForGroup(group).length}
    </span>
  );
}
