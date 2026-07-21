"use client";

import { useMemo, useState } from "react";
import {
  keepPreviousData,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  Archive,
  ArrowDown,
  ArrowUp,
  ArrowUpCircle,
  Check,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  CircleAlert,
  CircleCheck,
  CircleX,
  Clipboard,
  Columns3,
  Database,
  Download,
  Eye,
  FileJson,
  Filter,
  LoaderCircle,
  MoreHorizontal,
  Pencil,
  Plus,
  RefreshCw,
  RotateCcw,
  Search,
  Trash2,
  X,
} from "lucide-react";
import { toast } from "sonner";

import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { useDialogFocus } from "@/hooks/use-dialog-focus";
import {
  deleteRow,
  downloadText,
  fetchRows,
  humanizeIdentifier,
  inferMetadata,
  insertRow,
  rowsToCsv,
  setArchived,
  updateRow,
} from "@/lib/admin-data";
import type {
  EntityDefinition,
  RowData,
  SortDirection,
  TableMetadata,
} from "@/lib/admin-types";
import { capabilitiesFor } from "@/lib/entity-registry";

import { ConfirmDialog } from "./confirm-dialog";
import { EntityForm } from "./entity-form";
import styles from "./entity.module.css";

interface EntityTableProps {
  client: SupabaseClient;
  entity: EntityDefinition;
  metadata?: TableMetadata;
  schemaError?: string | null;
  compactHeader?: boolean;
}

type FormState =
  | { mode: "create"; row?: undefined }
  | { mode: "edit"; row: RowData }
  | null;

type DestructiveAction =
  | { type: "archive" | "restore" | "delete"; row: RowData }
  | null;

type WorkflowActionType =
  | "advance-batch"
  | "approve-batch-change"
  | "reject-batch-change"
  | "approve-attendance-correction"
  | "reject-attendance-correction";

type WorkflowAction = { type: WorkflowActionType; row: RowData } | null;

const WORKFLOW_DIALOG_COPY: Record<
  WorkflowActionType,
  { confirmLabel: string; dangerous: boolean; description: string; title: string }
> = {
  "advance-batch": {
    confirmLabel: "Advance batch",
    dangerous: false,
    description:
      "The batch will move to its next term, or graduate if it is already at the program's final term. The operation is audited.",
    title: "Advance this batch?",
  },
  "approve-batch-change": {
    confirmLabel: "Approve request",
    dangerous: false,
    description:
      "The destination batch will be written to the student's profile and the request will be accepted in one transaction.",
    title: "Approve this batch change?",
  },
  "reject-batch-change": {
    confirmLabel: "Reject request",
    dangerous: true,
    description:
      "The request will be marked rejected and the student's current batch will remain unchanged.",
    title: "Reject this batch change?",
  },
  "approve-attendance-correction": {
    confirmLabel: "Approve correction",
    dangerous: false,
    description:
      "The attendance record and request review state will be updated together, with attendance history and an audit event recorded in the same transaction.",
    title: "Approve this attendance correction?",
  },
  "reject-attendance-correction": {
    confirmLabel: "Reject correction",
    dangerous: true,
    description:
      "The correction request will be rejected without changing the student's attendance record. The review is audited.",
    title: "Reject this attendance correction?",
  },
};

const PAGE_SIZES = [20, 50, 100];
const STATUS_COLUMNS = new Set([
  "role",
  "status",
  "state",
  "priority",
  "type",
  "scope",
  "category",
  "channel",
  "academic_system",
  "blood_group",
]);

const dateTimeFormatter = new Intl.DateTimeFormat("en-GB", {
  dateStyle: "medium",
  timeStyle: "short",
  timeZone: "Asia/Dhaka",
});

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

function isDateColumn(column: string): boolean {
  return (
    column.endsWith("_at") ||
    column.endsWith("_date") ||
    column === "last_donated" ||
    column === "exam_date" ||
    column === "schedule_date" ||
    column === "session_date"
  );
}

function isUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function badgeTone(value: string): string {
  if (/active|published|present|fulfilled|accepted|available|open|cr/i.test(value)) {
    return styles.badgeSuccess;
  }
  if (/urgent|deleted|cancelled|rejected|absent|suspended/i.test(value)) {
    return styles.badgeDanger;
  }
  if (/pending|scheduled|draft|high|delayed/i.test(value)) {
    return styles.badgeWarning;
  }
  if (/super_admin|university|exam|archived|graduated/i.test(value)) {
    return styles.badgePurple;
  }
  return styles.badgeNeutral;
}

function CellValue({ column, value }: { column: string; value: unknown }) {
  const [copied, setCopied] = useState(false);

  if (value === null || value === undefined || value === "") {
    return <span className={styles.nullValue}>NULL</span>;
  }

  if (typeof value === "boolean") {
    return (
      <span className={value ? styles.booleanTrue : styles.booleanFalse}>
        <span>{value ? <Check size={12} /> : <X size={12} />}</span>
        {value ? "Yes" : "No"}
      </span>
    );
  }

  if (typeof value === "object") {
    const json = JSON.stringify(value);
    return (
      <span className={styles.jsonValue} title={JSON.stringify(value, null, 2)}>
        <FileJson size={14} /> {json.length > 42 ? `${json.slice(0, 42)}…` : json}
      </span>
    );
  }

  const text = String(value);

  if (STATUS_COLUMNS.has(column)) {
    return (
      <span className={`${styles.badge} ${badgeTone(text)}`}>
        {humanizeIdentifier(text)}
      </span>
    );
  }

  if (isDateColumn(column) && /^\d{4}-\d{2}-\d{2}/.test(text)) {
    if (/^\d{4}-\d{2}-\d{2}$/.test(text)) {
      return <span className={styles.dateValue}>{text}</span>;
    }
    const date = new Date(text);
    if (!Number.isNaN(date.valueOf())) {
      return <span className={styles.dateValue}>{dateTimeFormatter.format(date)}</span>;
    }
  }

  if (isUrl(text)) {
    return (
      <a className={styles.cellLink} href={text} rel="noreferrer" target="_blank">
        {text.replace(/^https?:\/\//, "").slice(0, 34)}
      </a>
    );
  }

  if (isUuid(text)) {
    async function copy() {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1200);
    }

    return (
      <button className={styles.uuidValue} onClick={copy} title={text} type="button">
        <span>{`${text.slice(0, 8)}…${text.slice(-4)}`}</span>
        {copied ? <Check size={12} /> : <Clipboard size={12} />}
      </button>
    );
  }

  return (
    <span className={styles.textValue} title={text}>
      {text}
    </span>
  );
}

function RecordDrawer({
  entity,
  row,
  onClose,
  onEdit,
}: {
  entity: EntityDefinition;
  row: RowData;
  onClose: () => void;
  onEdit?: () => void;
}) {
  const dialogRef = useDialogFocus<HTMLElement>(true, onClose);

  return (
    <div className={styles.drawerBackdrop} role="presentation" onMouseDown={onClose}>
      <aside
        aria-labelledby="record-detail-title"
        aria-modal="true"
        className={styles.drawer}
        onMouseDown={(event) => event.stopPropagation()}
        ref={dialogRef}
        role="dialog"
        tabIndex={-1}
      >
        <header className={styles.drawerHeader}>
          <div>
            <span className={styles.eyebrow}>Complete database row</span>
            <h2 id="record-detail-title">{entity.singular} details</h2>
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
        <div className={styles.recordDetails}>
          {Object.entries(row).map(([column, value]) => (
            <div className={styles.detailRow} key={column}>
              <span>{humanizeIdentifier(column)}</span>
              <div>
                {typeof value === "object" && value !== null ? (
                  <pre>{JSON.stringify(value, null, 2)}</pre>
                ) : (
                  <CellValue column={column} value={value} />
                )}
              </div>
            </div>
          ))}
        </div>
        <footer className={styles.drawerFooter}>
          <span className={styles.monoHint}>{Object.keys(row).length} columns</span>
          <div>
            <button className={styles.secondaryButton} onClick={onClose} type="button">
              Close
            </button>
            {onEdit ? (
              <button className={styles.primaryButton} onClick={onEdit} type="button">
                <Pencil size={16} /> Edit record
              </button>
            ) : null}
          </div>
        </footer>
      </aside>
    </div>
  );
}

function displayColumns(
  entity: EntityDefinition,
  metadata: TableMetadata,
): string[] {
  const available = new Set(metadata.columns.map((column) => column.name));
  const preferred = entity.preferredColumns.filter((column) => available.has(column));
  if (preferred.length >= 4) return preferred;

  const extras = metadata.columns
    .map((column) => column.name)
    .filter((column) => !preferred.includes(column));
  return [...preferred, ...extras].slice(0, 8);
}

export function EntityTable({
  client,
  entity,
  metadata: providedMetadata,
  schemaError,
  compactHeader = false,
}: EntityTableProps) {
  const queryClient = useQueryClient();
  const capabilities = capabilitiesFor(entity);
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(20);
  const [searchInput, setSearchInput] = useState("");
  const search = useDebouncedValue(searchInput);
  const [sort, setSort] = useState(entity.defaultSort);
  const [direction, setDirection] = useState<SortDirection>(
    entity.defaultDirection ?? "asc",
  );
  const [includeArchived, setIncludeArchived] = useState(false);
  const [form, setForm] = useState<FormState>(null);
  const [detailRow, setDetailRow] = useState<RowData | null>(null);
  const [destructiveAction, setDestructiveAction] =
    useState<DestructiveAction>(null);
  const [workflowAction, setWorkflowAction] = useState<WorkflowAction>(null);
  const [mutating, setMutating] = useState(false);
  const [columnSelections, setColumnSelections] = useState<
    Record<string, string[]>
  >({});

  const rowsQuery = useQuery({
    queryKey: [
      "rows",
      entity.name,
      page,
      pageSize,
      search,
      sort,
      direction,
      includeArchived,
    ],
    queryFn: () =>
      fetchRows(client, entity, {
        page,
        pageSize,
        search,
        sort,
        direction,
        includeArchived,
      }),
    placeholderData: keepPreviousData,
  });

  const metadata = useMemo(
    () => providedMetadata ?? inferMetadata(entity, rowsQuery.data?.rows ?? []),
    [entity, providedMetadata, rowsQuery.data?.rows],
  );

  const availableColumns = useMemo(
    () => metadata.columns.map((column) => column.name),
    [metadata.columns],
  );

  const visibleColumns = useMemo(() => {
    const selected = columnSelections[entity.name];
    const validSelected = selected?.filter((column) =>
      availableColumns.includes(column),
    );
    return validSelected?.length
      ? validSelected
      : displayColumns(entity, metadata);
  }, [availableColumns, columnSelections, entity, metadata]);

  const totalPages = Math.max(1, Math.ceil((rowsQuery.data?.count ?? 0) / pageSize));
  const rows = rowsQuery.data?.rows ?? [];
  const hasRealMetadata = Boolean(providedMetadata?.columns.length);

  function toggleColumn(column: string) {
    setColumnSelections((selections) => {
      const current =
        selections[entity.name] ?? displayColumns(entity, metadata);
      const next = current.includes(column)
        ? current.filter((value) => value !== column)
        : [...current, column];
      if (next.length === 0) return selections;
      return { ...selections, [entity.name]: next };
    });
  }

  function changeSort(column: string) {
    if (sort === column) {
      setDirection((current) => (current === "asc" ? "desc" : "asc"));
    } else {
      setSort(column);
      setDirection("asc");
    }
    setPage(0);
  }

  async function refresh() {
    await queryClient.invalidateQueries({ queryKey: ["rows", entity.name] });
    toast.success(`${entity.label} refreshed`);
  }

  async function saveForm(values: RowData) {
    setMutating(true);
    try {
      if (form?.mode === "create") {
        await insertRow(client, entity.name, values);
        toast.success(`${humanizeIdentifier(entity.singular)} created`);
      } else if (form?.mode === "edit") {
        if (entity.name === "profiles") {
          const {
            data: { user },
          } = await client.auth.getUser();
          if (
            user?.id === form.row.id &&
            values.status !== undefined &&
            values.status !== form.row.status
          ) {
            throw new Error(
              "You cannot change your own administrator status from this panel.",
            );
          }
          if (
            form.row.role === "cr" &&
            values.batch_id !== undefined &&
            values.batch_id !== form.row.batch_id
          ) {
            throw new Error(
              "Unpromote this CR before moving them to another batch.",
            );
          }
        }
        await updateRow(client, metadata, form.row, values);
        toast.success(`${humanizeIdentifier(entity.singular)} updated`);
      }
      setForm(null);
      await queryClient.invalidateQueries({ queryKey: ["rows", entity.name] });
    } finally {
      setMutating(false);
    }
  }

  async function confirmWorkflowAction() {
    if (!workflowAction) return;
    setMutating(true);
    try {
      if (workflowAction.type === "advance-batch") {
        const { error } = await client.rpc("advance_batch", {
          target_batch: workflowAction.row.id,
        });
        if (error) throw error;
        toast.success("Batch advanced", {
          description: "The term/status change and audit event were committed together.",
        });
        await queryClient.invalidateQueries({ queryKey: ["rows", "batches"] });
      } else if (
        workflowAction.type === "approve-batch-change" ||
        workflowAction.type === "reject-batch-change"
      ) {
        const approve = workflowAction.type === "approve-batch-change";
        const { error } = await client.rpc("review_batch_change_request", {
          request_id: workflowAction.row.id,
          approve,
        });
        if (error) throw error;
        toast.success(approve ? "Batch change approved" : "Batch change rejected", {
          description: approve
            ? "The student's profile batch and request were updated atomically."
            : "The request was closed without moving the student.",
        });
        await Promise.all([
          queryClient.invalidateQueries({ queryKey: ["rows", "batch_change_requests"] }),
          queryClient.invalidateQueries({ queryKey: ["rows", "profiles"] }),
        ]);
      } else {
        const approve = workflowAction.type === "approve-attendance-correction";
        const { error } = await client.rpc(
          "review_attendance_correction_request",
          {
            request_id: workflowAction.row.id,
            approve,
          },
        );
        if (error) throw error;
        toast.success(approve ? "Attendance correction approved" : "Attendance correction rejected", {
          description: approve
            ? "The attendance record and correction request were updated atomically."
            : "The request was closed without changing the attendance record.",
        });
        await Promise.all([
          queryClient.invalidateQueries({
            queryKey: ["rows", "attendance_correction_requests"],
          }),
          queryClient.invalidateQueries({ queryKey: ["rows", "attendance_records"] }),
          queryClient.invalidateQueries({ queryKey: ["rows", "attendance_history"] }),
        ]);
      }
      await queryClient.invalidateQueries({ queryKey: ["dashboard"] });
      setWorkflowAction(null);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "The workflow action failed.");
    } finally {
      setMutating(false);
    }
  }

  async function confirmDestructiveAction() {
    if (!destructiveAction) return;
    setMutating(true);
    try {
      if (destructiveAction.type === "delete") {
        await deleteRow(client, metadata, destructiveAction.row);
        toast.success("Record permanently deleted");
      } else {
        const archive = destructiveAction.type === "archive";
        await setArchived(client, metadata, destructiveAction.row, archive);
        toast.success(archive ? "Record archived" : "Record restored");
      }
      setDestructiveAction(null);
      await queryClient.invalidateQueries({ queryKey: ["rows", entity.name] });
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "The operation failed.");
    } finally {
      setMutating(false);
    }
  }

  function exportPage() {
    if (rows.length === 0) return;
    const columns = metadata.columns.length
      ? metadata.columns.map((column) => column.name)
      : Object.keys(rows[0]);
    downloadText(
      rowsToCsv(rows, columns),
      `${entity.name}-${new Date().toISOString().slice(0, 10)}.csv`,
      "text/csv;charset=utf-8",
    );
    toast.success(`${rows.length} visible rows exported`);
  }

  const actionDescription = destructiveAction
    ? destructiveAction.type === "delete"
      ? "This is a permanent database delete. Related records or foreign-key rules may prevent it. This action cannot be undone."
      : destructiveAction.type === "archive"
        ? "The record will be hidden from normal app queries but retained for history and restoration."
        : "The record will become visible to normal app queries again."
    : "";

  return (
    <section className={styles.entityCard}>
      {!compactHeader ? (
        <header className={styles.entityHeader}>
          <div>
            <div className={styles.titleLine}>
              <h2>{entity.label}</h2>
              {entity.readOnly ? <span className={styles.readOnlyBadge}>Read only</span> : null}
              {entity.softDelete ? <span className={styles.softDeleteBadge}>Archive enabled</span> : null}
            </div>
            <p>{entity.description}</p>
          </div>
          <div className={styles.headerActions}>
            <button className={styles.secondaryButton} onClick={refresh} type="button">
              <RefreshCw className={rowsQuery.isFetching ? styles.spin : undefined} size={16} />
              Refresh
            </button>
            {capabilities.create ? (
              <button
                className={styles.primaryButton}
                disabled={!hasRealMetadata}
                onClick={() => setForm({ mode: "create" })}
                title={hasRealMetadata ? undefined : "Apply the admin support migration first"}
                type="button"
              >
                <Plus size={17} /> New {entity.singular}
              </button>
            ) : null}
          </div>
        </header>
      ) : null}

      {entity.managedRoute ? (
        <div className={styles.infoBanner}>
          <CircleAlert size={18} />
          <span>
            This relation is protected from raw edits to keep role and assignment data
            consistent. Use the dedicated management workflow.
          </span>
          <a href={entity.managedRoute}>Open manager</a>
        </div>
      ) : null}

      {schemaError ? (
        <div className={styles.warningBanner}>
          <CircleAlert size={18} />
          <span>
            Schema metadata is unavailable. Existing rows remain readable, but generated
            forms require the admin support migration. {schemaError}
          </span>
        </div>
      ) : null}

      <div className={styles.tableToolbar}>
        <label className={styles.searchBox}>
          <Search size={17} />
          <input
            aria-label={`Search ${entity.label}`}
            disabled={entity.searchColumns.length === 0}
            onChange={(event) => {
              setSearchInput(event.target.value);
              setPage(0);
            }}
            placeholder={
              entity.searchColumns.length ? `Search ${entity.label.toLowerCase()}…` : "No text fields to search"
            }
            value={searchInput}
          />
          {searchInput ? (
            <button
              aria-label="Clear search"
              onClick={() => {
                setSearchInput("");
                setPage(0);
              }}
              type="button"
            >
              <X size={15} />
            </button>
          ) : null}
        </label>

        <div className={styles.toolbarActions}>
          {entity.softDelete ? (
            <label className={styles.archiveToggle}>
              <input
                checked={includeArchived}
                onChange={(event) => {
                  setIncludeArchived(event.target.checked);
                  setPage(0);
                }}
                type="checkbox"
              />
              <Archive size={15} /> Include archived
            </label>
          ) : null}

          <details className={styles.columnPicker}>
            <summary>
              <Columns3 size={16} /> Columns
            </summary>
            <div>
              <strong>Visible columns</strong>
              <span>{visibleColumns.length} selected</span>
              <ul>
                {availableColumns.map((column) => (
                  <li key={column}>
                    <label>
                      <input
                        checked={visibleColumns.includes(column)}
                        onChange={() => toggleColumn(column)}
                        type="checkbox"
                      />
                      {humanizeIdentifier(column)}
                    </label>
                  </li>
                ))}
              </ul>
            </div>
          </details>

          <button className={styles.toolbarButton} disabled={rows.length === 0} onClick={exportPage} type="button">
            <Download size={16} /> Export page
          </button>
        </div>
      </div>

      <div className={styles.tableMeta}>
        <span>
          <Database size={14} />
          {rowsQuery.isLoading
            ? "Counting rows…"
            : `${(rowsQuery.data?.count ?? 0).toLocaleString()} total rows`}
        </span>
        {search ? (
          <span>
            <Filter size={14} /> Filtered by “{search}”
          </span>
        ) : null}
        {rowsQuery.isFetching && !rowsQuery.isLoading ? (
          <span className={styles.refreshing}>
            <LoaderCircle className={styles.spin} size={14} /> Updating
          </span>
        ) : null}
      </div>

      <div className={styles.tableViewport}>
        <table className={styles.dataTable}>
          <thead>
            <tr>
              {visibleColumns.map((column) => (
                <th key={column}>
                  <button onClick={() => changeSort(column)} type="button">
                    {humanizeIdentifier(column)}
                    {sort === column ? (
                      direction === "asc" ? (
                        <ArrowUp size={13} />
                      ) : (
                        <ArrowDown size={13} />
                      )
                    ) : (
                      <ChevronsUpDown className={styles.sortIdle} size={13} />
                    )}
                  </button>
                </th>
              ))}
              <th className={styles.actionsColumn}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {rowsQuery.isLoading ? (
              Array.from({ length: Math.min(pageSize, 8) }).map((_, index) => (
                <tr className={styles.skeletonRow} key={index}>
                  {visibleColumns.map((column) => (
                    <td key={column}>
                      <span />
                    </td>
                  ))}
                  <td><span /></td>
                </tr>
              ))
            ) : rows.length > 0 ? (
              rows.map((row, rowIndex) => (
                <tr
                  className={row.deleted_at ? styles.archivedRow : undefined}
                  key={String(row.id ?? `${entity.name}-${rowIndex}`)}
                >
                  {visibleColumns.map((column) => (
                    <td key={column}>
                      <CellValue column={column} value={row[column]} />
                    </td>
                  ))}
                  <td className={styles.rowActions}>
                    <button aria-label="View row" onClick={() => setDetailRow(row)} title="View all columns" type="button">
                      <Eye size={16} />
                    </button>
                    {(capabilities.update || capabilities.delete) && !entity.managedRoute ? (
                      <details className={styles.actionMenu}>
                        <summary aria-label="More actions">
                          <MoreHorizontal size={17} />
                        </summary>
                        <div>
                          {capabilities.update ? (
                            <button onClick={() => setForm({ mode: "edit", row })} type="button">
                              <Pencil size={15} /> Edit
                            </button>
                          ) : null}
                          {entity.name === "batch_change_requests" && row.status === "pending" ? (
                            <>
                              <button
                                onClick={() => setWorkflowAction({ type: "approve-batch-change", row })}
                                type="button"
                              >
                                <CircleCheck size={15} /> Approve request
                              </button>
                              <button
                                onClick={() => setWorkflowAction({ type: "reject-batch-change", row })}
                                type="button"
                              >
                                <CircleX size={15} /> Reject request
                              </button>
                            </>
                          ) : null}
                          {entity.name === "attendance_correction_requests" && row.status === "pending" ? (
                            <>
                              <button
                                onClick={() =>
                                  setWorkflowAction({
                                    type: "approve-attendance-correction",
                                    row,
                                  })
                                }
                                type="button"
                              >
                                <CircleCheck size={15} /> Approve correction
                              </button>
                              <button
                                onClick={() =>
                                  setWorkflowAction({
                                    type: "reject-attendance-correction",
                                    row,
                                  })
                                }
                                type="button"
                              >
                                <CircleX size={15} /> Reject correction
                              </button>
                            </>
                          ) : null}
                          {entity.name === "batches" && row.status !== "graduated" ? (
                            <button
                              onClick={() => setWorkflowAction({ type: "advance-batch", row })}
                              type="button"
                            >
                              <ArrowUpCircle size={15} /> Advance batch
                            </button>
                          ) : null}
                          {entity.softDelete && capabilities.update ? (
                            <button
                              onClick={() =>
                                setDestructiveAction({
                                  type: row.deleted_at ? "restore" : "archive",
                                  row,
                                })
                              }
                              type="button"
                            >
                              {row.deleted_at ? <RotateCcw size={15} /> : <Archive size={15} />}
                              {row.deleted_at ? "Restore" : "Archive"}
                            </button>
                          ) : null}
                          {capabilities.delete ? (
                            <button
                              className={styles.menuDanger}
                              onClick={() => setDestructiveAction({ type: "delete", row })}
                              type="button"
                            >
                              <Trash2 size={15} /> Delete permanently
                            </button>
                          ) : null}
                        </div>
                      </details>
                    ) : null}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td className={styles.emptyTable} colSpan={visibleColumns.length + 1}>
                  <span><Database size={24} /></span>
                  <strong>No records found</strong>
                  <p>
                    {search
                      ? "Try a different search term or clear the current filters."
                      : `There are no ${entity.label.toLowerCase()} in this view yet.`}
                  </p>
                  {search ? (
                    <button className={styles.secondaryButton} onClick={() => setSearchInput("")} type="button">
                      Clear search
                    </button>
                  ) : null}
                </td>
              </tr>
            )}
          </tbody>
        </table>

        {rowsQuery.error ? (
          <div className={styles.tableError} role="alert">
            <CircleAlert size={22} />
            <div>
              <strong>Could not load {entity.label.toLowerCase()}</strong>
              <p>
                {rowsQuery.error instanceof Error
                  ? rowsQuery.error.message
                  : "Check the relation, RLS policies, and your admin session."}
              </p>
            </div>
            <button className={styles.secondaryButton} onClick={() => rowsQuery.refetch()} type="button">
              Try again
            </button>
          </div>
        ) : null}
      </div>

      <footer className={styles.pagination}>
        <label>
          Rows per page
          <select
            onChange={(event) => {
              setPageSize(Number(event.target.value));
              setPage(0);
            }}
            value={pageSize}
          >
            {PAGE_SIZES.map((size) => (
              <option key={size} value={size}>{size}</option>
            ))}
          </select>
        </label>
        <span>
          {rowsQuery.data?.count
            ? `${page * pageSize + 1}–${Math.min((page + 1) * pageSize, rowsQuery.data.count)} of ${rowsQuery.data.count.toLocaleString()}`
            : "0 rows"}
        </span>
        <div>
          <button aria-label="Previous page" disabled={page <= 0} onClick={() => setPage((value) => value - 1)} type="button">
            <ChevronLeft size={17} />
          </button>
          <span>Page {page + 1} of {totalPages}</span>
          <button aria-label="Next page" disabled={page + 1 >= totalPages} onClick={() => setPage((value) => value + 1)} type="button">
            <ChevronRight size={17} />
          </button>
        </div>
      </footer>

      {form && hasRealMetadata ? (
        <EntityForm
          busy={mutating}
          client={client}
          entity={entity}
          initial={form.row}
          metadata={metadata}
          mode={form.mode}
          onClose={() => setForm(null)}
          onSubmit={saveForm}
        />
      ) : null}

      {detailRow ? (
        <RecordDrawer
          entity={entity}
          onClose={() => setDetailRow(null)}
          onEdit={
            capabilities.update && !entity.managedRoute
              ? () => {
                  setForm({ mode: "edit", row: detailRow });
                  setDetailRow(null);
                }
              : undefined
          }
          row={detailRow}
        />
      ) : null}

      <ConfirmDialog
        busy={mutating}
        confirmLabel={
          destructiveAction?.type === "delete"
            ? "Delete permanently"
            : destructiveAction?.type === "archive"
              ? "Archive record"
              : "Restore record"
        }
        dangerous={destructiveAction?.type === "delete"}
        description={actionDescription}
        onClose={() => setDestructiveAction(null)}
        onConfirm={confirmDestructiveAction}
        open={Boolean(destructiveAction)}
        title={
          destructiveAction?.type === "delete"
            ? "Permanently delete this record?"
            : destructiveAction?.type === "archive"
              ? "Archive this record?"
              : "Restore this record?"
        }
      />
      <ConfirmDialog
        busy={mutating}
        confirmLabel={
          WORKFLOW_DIALOG_COPY[
            workflowAction?.type ?? "reject-batch-change"
          ].confirmLabel
        }
        dangerous={
          WORKFLOW_DIALOG_COPY[
            workflowAction?.type ?? "reject-batch-change"
          ].dangerous
        }
        description={
          WORKFLOW_DIALOG_COPY[
            workflowAction?.type ?? "reject-batch-change"
          ].description
        }
        onClose={() => setWorkflowAction(null)}
        onConfirm={confirmWorkflowAction}
        open={Boolean(workflowAction)}
        title={
          WORKFLOW_DIALOG_COPY[
            workflowAction?.type ?? "reject-batch-change"
          ].title
        }
      />
    </section>
  );
}
