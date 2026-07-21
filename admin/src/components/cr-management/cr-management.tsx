"use client";

import { useMemo, useState } from "react";
import {
  keepPreviousData,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  BadgeCheck,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  Crown,
  Filter,
  GraduationCap,
  LoaderCircle,
  Search,
  ShieldCheck,
  ShieldMinus,
  ShieldPlus,
  UserRound,
  UsersRound,
} from "lucide-react";
import { toast } from "sonner";

import { ConfirmDialog } from "@/components/data/confirm-dialog";
import { useDebouncedValue } from "@/hooks/use-debounced-value";
import { createBrowserClient } from "@/lib/supabase/client";

import styles from "./cr-management.module.css";

interface ProfileRow {
  id: string;
  full_name: string;
  email: string;
  student_id: string | null;
  roll: string | null;
  role: "student" | "cr" | "super_admin";
  status: "active" | "suspended" | "archived" | "deleted";
  batch_id: string | null;
  department_id: string | null;
  created_at: string;
  deleted_at: string | null;
}

interface AssignmentRow {
  id: string;
  profile_id: string;
  batch_id: string;
  assigned_by: string | null;
  created_at: string;
}

interface BatchRow {
  id: string;
  name: string | null;
  session: string;
  admission_year: number;
  program_id: string;
  status: string;
}

interface ProgramRow {
  id: string;
  code: string;
  department_id: string;
}

interface DepartmentRow {
  id: string;
  name: string;
  code: string;
}

interface CrReferenceData {
  assignments: AssignmentRow[];
  batches: BatchRow[];
  programs: ProgramRow[];
  departments: DepartmentRow[];
  activeStudents: number;
  activeCrs: number;
}

interface ProfilePage {
  profiles: ProfileRow[];
  count: number;
}

interface ProfilePageOptions {
  page: number;
  pageSize: number;
  search: string;
  role: string;
  batchId: string;
}

interface PendingChange {
  profile: ProfileRow;
  promote: boolean;
}

const client = createBrowserClient();
const PAGE_SIZES = [20, 50, 100];
const ASSIGNMENT_PAGE_SIZE = 1000;

function safeSearchValue(value: string): string {
  return value
    .replace(/[(),%*'"\\]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 120);
}

async function fetchAllAssignments(): Promise<AssignmentRow[]> {
  const rows: AssignmentRow[] = [];
  let start = 0;

  for (;;) {
    const { data, error, count } = await client
      .from("cr_assignments")
      .select("id, profile_id, batch_id, assigned_by, created_at", {
        count: "exact",
      })
      .order("created_at", { ascending: false })
      .order("id", { ascending: true })
      .range(start, start + ASSIGNMENT_PAGE_SIZE - 1);

    if (error) throw error;
    const page = (data ?? []) as AssignmentRow[];
    rows.push(...page);
    start += page.length;
    if (page.length === 0 || (count !== null && start >= count)) return rows;
  }
}

async function fetchCrReferenceData(): Promise<CrReferenceData> {
  const [assignments, batches, programs, departments, activeStudents, activeCrs] =
    await Promise.all([
      fetchAllAssignments(),
      client
        .from("batches")
        .select("id, name, session, admission_year, program_id, status")
        .order("admission_year", { ascending: false }),
      client.from("programs").select("id, code, department_id"),
      client.from("departments").select("id, name, code").order("name"),
      client
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "student")
        .eq("status", "active")
        .is("deleted_at", null),
      client
        .from("profiles")
        .select("id", { count: "exact", head: true })
        .eq("role", "cr")
        .eq("status", "active")
        .is("deleted_at", null),
    ]);

  const failed = [batches, programs, departments, activeStudents, activeCrs].find(
    (response) => response.error,
  );
  if (failed?.error) throw failed.error;

  return {
    assignments,
    batches: (batches.data ?? []) as BatchRow[],
    programs: (programs.data ?? []) as ProgramRow[],
    departments: (departments.data ?? []) as DepartmentRow[],
    activeStudents: activeStudents.count ?? 0,
    activeCrs: activeCrs.count ?? 0,
  };
}

async function fetchProfilePage({
  page,
  pageSize,
  search,
  role,
  batchId,
}: ProfilePageOptions): Promise<ProfilePage> {
  const start = page * pageSize;
  let query = client
    .from("profiles")
    .select(
      "id, full_name, email, student_id, roll, role, status, batch_id, department_id, created_at, deleted_at",
      { count: "exact" },
    )
    .in("role", ["student", "cr"]);

  if (role !== "all") query = query.eq("role", role);
  if (batchId !== "all") query = query.eq("batch_id", batchId);

  const term = safeSearchValue(search);
  if (term) {
    query = query.or(
      ["full_name", "email", "student_id", "roll"]
        .map((column) => `${column}.ilike.%${term}%`)
        .join(","),
    );
  }

  const { data, error, count } = await query
    .order("created_at", { ascending: false })
    .order("id", { ascending: true })
    .range(start, start + pageSize - 1);

  if (error) throw error;
  return {
    profiles: (data ?? []) as ProfileRow[],
    count: count ?? 0,
  };
}

function initials(name: string): string {
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

export function CrManagement() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const debouncedSearch = useDebouncedValue(search);
  const [roleFilter, setRoleFilter] = useState("all");
  const [batchFilter, setBatchFilter] = useState("all");
  const [page, setPage] = useState(0);
  const [pageSize, setPageSize] = useState(20);
  const [pending, setPending] = useState<PendingChange | null>(null);
  const [mutating, setMutating] = useState(false);
  const referenceQuery = useQuery({
    queryKey: ["cr-management-reference"],
    queryFn: fetchCrReferenceData,
    staleTime: 2 * 60 * 1000,
  });
  const profilesQuery = useQuery({
    queryKey: [
      "cr-management-profiles",
      page,
      pageSize,
      debouncedSearch,
      roleFilter,
      batchFilter,
    ],
    queryFn: () =>
      fetchProfilePage({
        page,
        pageSize,
        search: debouncedSearch,
        role: roleFilter,
        batchId: batchFilter,
      }),
    placeholderData: keepPreviousData,
  });
  const data = referenceQuery.data;
  const profiles = profilesQuery.data?.profiles ?? [];
  const profileCount = profilesQuery.data?.count ?? 0;
  const totalPages = Math.max(1, Math.ceil(profileCount / pageSize));
  const isLoading = referenceQuery.isLoading || profilesQuery.isLoading;
  const isFetching = referenceQuery.isFetching || profilesQuery.isFetching;
  const error = referenceQuery.error ?? profilesQuery.error;

  async function refetch() {
    await Promise.all([referenceQuery.refetch(), profilesQuery.refetch()]);
  }

  const batchById = useMemo(
    () => new Map(data?.batches.map((batch) => [batch.id, batch]) ?? []),
    [data?.batches],
  );
  const programById = useMemo(
    () => new Map(data?.programs.map((program) => [program.id, program]) ?? []),
    [data?.programs],
  );
  const departmentById = useMemo(
    () => new Map(data?.departments.map((department) => [department.id, department]) ?? []),
    [data?.departments],
  );
  const assignmentsByProfile = useMemo(() => {
    const map = new Map<string, AssignmentRow[]>();
    for (const assignment of data?.assignments ?? []) {
      map.set(assignment.profile_id, [
        ...(map.get(assignment.profile_id) ?? []),
        assignment,
      ]);
    }
    return map;
  }, [data?.assignments]);
  const occupancyByBatch = useMemo(() => {
    const map = new Map<string, number>();
    for (const assignment of data?.assignments ?? []) {
      map.set(assignment.batch_id, (map.get(assignment.batch_id) ?? 0) + 1);
    }
    return map;
  }, [data?.assignments]);

  const activeCrCount = data?.activeCrs ?? 0;
  const activeStudents = data?.activeStudents ?? 0;
  const fullBatches = [...occupancyByBatch.values()].filter((count) => count >= 2).length;
  const representedBatches = [...occupancyByBatch.values()].filter((count) => count > 0).length;

  function departmentFor(profile: ProfileRow): DepartmentRow | undefined {
    if (profile.department_id) return departmentById.get(profile.department_id);
    const batch = profile.batch_id ? batchById.get(profile.batch_id) : undefined;
    const program = batch ? programById.get(batch.program_id) : undefined;
    return program ? departmentById.get(program.department_id) : undefined;
  }

  async function applyChange() {
    if (!pending) return;
    setMutating(true);
    try {
      const { data: result, error: rpcError } = await client.rpc("admin_set_cr", {
        target_profile_id: pending.profile.id,
        promote: pending.promote,
        target_batch_id: pending.profile.batch_id,
      });
      if (rpcError) throw rpcError;

      toast.success(
        pending.promote
          ? `${pending.profile.full_name} is now a CR`
          : `${pending.profile.full_name} is now a student`,
        {
          description:
            result && typeof result === "object" && "audit_id" in result
              ? `Audit event #${String(result.audit_id)} recorded.`
              : "The role and assignment were updated atomically.",
        },
      );
      const leavesCurrentRoleFilter =
        (pending.promote && roleFilter === "student") ||
        (!pending.promote && roleFilter === "cr");
      if (leavesCurrentRoleFilter && profiles.length === 1 && page > 0) {
        setPage((current) => current - 1);
      }
      setPending(null);
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["cr-management-reference"] }),
        queryClient.invalidateQueries({ queryKey: ["cr-management-profiles"] }),
        queryClient.invalidateQueries({ queryKey: ["rows", "profiles"] }),
        queryClient.invalidateQueries({ queryKey: ["rows", "cr_assignments"] }),
        queryClient.invalidateQueries({ queryKey: ["dashboard"] }),
      ]);
    } catch (changeError) {
      toast.error(pending.promote ? "Promotion failed" : "Unpromotion failed", {
        description:
          changeError instanceof Error
            ? changeError.message
            : "The database rejected the role change.",
      });
    } finally {
      setMutating(false);
    }
  }

  return (
    <div className={styles.page}>
      <header className={styles.pageHeader}>
        <div>
          <span>Accounts · authorization</span>
          <h1>CR management</h1>
          <p>
            Promote registered students into class representatives or return CRs to
            student access. Every change is atomic, capacity-checked, and audited.
          </p>
        </div>
        <div className={styles.securityPill}>
          <ShieldCheck size={17} />
          <span><b>Protected workflow</b> Super admin only</span>
        </div>
      </header>

      <div className={styles.stats}>
        <article>
          <span className={styles.blue}><UserRound size={20} /></span>
          <div><p>Active students</p><strong>{activeStudents.toLocaleString()}</strong><small>student accounts in good standing</small></div>
        </article>
        <article>
          <span className={styles.green}><Crown size={20} /></span>
          <div><p>Active CRs</p><strong>{activeCrCount.toLocaleString()}</strong><small>with elevated access</small></div>
        </article>
        <article>
          <span className={styles.purple}><UsersRound size={20} /></span>
          <div><p>Represented batches</p><strong>{representedBatches.toLocaleString()}</strong><small>at least one CR</small></div>
        </article>
        <article>
          <span className={styles.gold}><BadgeCheck size={20} /></span>
          <div><p>At capacity</p><strong>{fullBatches.toLocaleString()}</strong><small>two of two CRs</small></div>
        </article>
      </div>

      <section className={styles.panel}>
        <header className={styles.panelHeader}>
          <div>
            <h2>Registered student accounts</h2>
            <p>{profileCount.toLocaleString()} accounts match the current filters</p>
          </div>
          {isFetching && !isLoading ? <LoaderCircle className={styles.spin} size={17} /> : null}
        </header>

        <div className={styles.toolbar}>
          <label className={styles.searchBox}>
            <Search size={17} />
            <input
              onChange={(event) => {
                setSearch(event.target.value);
                setPage(0);
              }}
              placeholder="Search name, email, student ID, or roll…"
              value={search}
            />
          </label>
          <label className={styles.filterSelect}>
            <Filter size={15} />
            <select
              onChange={(event) => {
                setRoleFilter(event.target.value);
                setPage(0);
              }}
              value={roleFilter}
            >
              <option value="all">All roles</option>
              <option value="student">Students</option>
              <option value="cr">Class representatives</option>
            </select>
          </label>
          <label className={styles.filterSelect}>
            <GraduationCap size={15} />
            <select
              onChange={(event) => {
                setBatchFilter(event.target.value);
                setPage(0);
              }}
              value={batchFilter}
            >
              <option value="all">All batches</option>
              {data?.batches.map((batch) => (
                <option key={batch.id} value={batch.id}>
                  {batch.name || batch.session} · {batch.session}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className={styles.tableWrap}>
          <table>
            <thead>
              <tr>
                <th>Student</th>
                <th>Department</th>
                <th>Batch</th>
                <th>Account status</th>
                <th>Batch CR slots</th>
                <th>Role</th>
                <th aria-label="Actions" />
              </tr>
            </thead>
            <tbody>
              {isLoading ? (
                Array.from({ length: 7 }).map((_, index) => (
                  <tr className={styles.skeleton} key={index}>
                    {Array.from({ length: 7 }).map((__, cell) => <td key={cell}><span /></td>)}
                  </tr>
                ))
              ) : profiles.length ? (
                profiles.map((profile) => {
                  const batch = profile.batch_id ? batchById.get(profile.batch_id) : undefined;
                  const department = departmentFor(profile);
                  const occupancy = profile.batch_id
                    ? occupancyByBatch.get(profile.batch_id) ?? 0
                    : 0;
                  const assignments = assignmentsByProfile.get(profile.id) ?? [];
                  const consistentCr =
                    profile.role === "cr" &&
                    assignments.length === 1 &&
                    assignments[0].batch_id === profile.batch_id;
                  const canPromote =
                    profile.role === "student" &&
                    profile.status === "active" &&
                    !profile.deleted_at &&
                    Boolean(profile.batch_id) &&
                    occupancy < 2;

                  return (
                    <tr key={profile.id}>
                      <td>
                        <div className={styles.studentCell}>
                          <span>{initials(profile.full_name)}</span>
                          <div>
                            <strong>{profile.full_name}</strong>
                            <small>{profile.student_id || profile.roll || profile.email}</small>
                          </div>
                        </div>
                      </td>
                      <td>
                        <strong className={styles.normalText}>{department?.code ?? "—"}</strong>
                        <small className={styles.subText}>{department?.name ?? "Not assigned"}</small>
                      </td>
                      <td>
                        <strong className={styles.normalText}>{batch?.name || batch?.session || "No batch"}</strong>
                        {batch ? <small className={styles.subText}>{batch.session}</small> : null}
                      </td>
                      <td>
                        <span className={`${styles.badge} ${profile.status === "active" ? styles.activeBadge : styles.inactiveBadge}`}>
                          {profile.status}
                        </span>
                      </td>
                      <td>
                        {profile.batch_id ? (
                          <div className={styles.capacity}>
                            <div>{[0, 1].map((slot) => <span className={slot < occupancy ? styles.filledSlot : undefined} key={slot} />)}</div>
                            <small>{occupancy}/2 assigned</small>
                          </div>
                        ) : <span className={styles.muted}>Unavailable</span>}
                      </td>
                      <td>
                        <span className={`${styles.badge} ${profile.role === "cr" ? styles.crBadge : styles.studentBadge}`}>
                          {profile.role === "cr" ? <Crown size={12} /> : <UserRound size={12} />}
                          {profile.role === "cr" ? "Class representative" : "Student"}
                        </span>
                        {profile.role === "cr" && !consistentCr ? (
                          <small className={styles.driftWarning}>Assignment needs review</small>
                        ) : null}
                      </td>
                      <td className={styles.actionCell}>
                        {profile.role === "cr" ? (
                          <button className={styles.unpromoteButton} onClick={() => setPending({ profile, promote: false })} type="button">
                            <ShieldMinus size={15} /> Unpromote
                          </button>
                        ) : (
                          <button
                            className={styles.promoteButton}
                            disabled={!canPromote}
                            onClick={() => setPending({ profile, promote: true })}
                            title={
                              !profile.batch_id
                                ? "Assign the student to a batch first"
                                : occupancy >= 2
                                  ? "This batch already has two CRs"
                                  : profile.status !== "active" || profile.deleted_at
                                    ? "Only active students can be promoted"
                                    : undefined
                            }
                            type="button"
                          >
                            <ShieldPlus size={15} /> Promote
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td className={styles.empty} colSpan={7}>
                    <Search size={25} />
                    <strong>No matching accounts</strong>
                    <p>Clear one of the filters or try another search term.</p>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {error ? (
          <div className={styles.error}>
            <CircleAlert size={20} />
            <div>
              <strong>CR accounts could not be loaded</strong>
              <p>{error instanceof Error ? error.message : "Check the admin session and RLS policies."}</p>
            </div>
            <button onClick={() => refetch()} type="button">Try again</button>
          </div>
        ) : null}

        <footer className={styles.panelFooter}>
          <label className={styles.pageSize}>
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
          <span className={styles.pageRange}>
            {profileCount
              ? `${page * pageSize + 1}-${Math.min((page + 1) * pageSize, profileCount)} of ${profileCount.toLocaleString()}`
              : "0 accounts"}
          </span>
          <div className={styles.pageControls}>
            <button
              aria-label="Previous page"
              disabled={page === 0}
              onClick={() => setPage((current) => Math.max(0, current - 1))}
              type="button"
            >
              <ChevronLeft size={16} />
            </button>
            <span>Page {page + 1} of {totalPages}</span>
            <button
              aria-label="Next page"
              disabled={page + 1 >= totalPages}
              onClick={() => setPage((current) => current + 1)}
              type="button"
            >
              <ChevronRight size={16} />
            </button>
          </div>
          <div className={styles.capacityRule}>
            <ShieldCheck size={16} />
            <span>A batch may have at most two CRs. A student can represent only their own batch.</span>
          </div>
        </footer>
      </section>

      <ConfirmDialog
        busy={mutating}
        confirmLabel={pending?.promote ? "Promote to CR" : "Unpromote to student"}
        dangerous={!pending?.promote}
        description={
          pending?.promote
            ? `${pending.profile.full_name} will receive CR access for their current batch. Their role, assignment, Auth metadata, and audit event are updated in one database transaction.`
            : `${pending?.profile.full_name ?? "This CR"} will immediately lose CR management access. Their assignment will be removed and their role will return to student.`
        }
        onClose={() => setPending(null)}
        onConfirm={applyChange}
        open={Boolean(pending)}
        title={pending?.promote ? "Promote this student?" : "Remove CR access?"}
      />
    </div>
  );
}
