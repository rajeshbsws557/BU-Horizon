"use client";

import { useMemo, useState } from "react";
import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";

import { createBrowserClient } from "@/lib/supabase/client";

interface PendingProfile {
  id: string;
  full_name: string;
  email: string;
  personal_email: string | null;
  student_id: string | null;
  roll: string | null;
  batch_id: string | null;
  department_id: string | null;
  created_at: string;
}

interface BatchRow {
  id: string;
  name: string | null;
  session: string;
}

interface DepartmentRow {
  id: string;
  name: string;
  code: string;
}

interface ApprovalsData {
  profiles: PendingProfile[];
  batches: BatchRow[];
  departments: DepartmentRow[];
}

const client = createBrowserClient();

async function fetchApprovals(): Promise<ApprovalsData> {
  const [profiles, batches, departments] = await Promise.all([
    client
      .from("profiles")
      .select(
        "id, full_name, email, personal_email, student_id, roll, batch_id, department_id, created_at",
      )
      .eq("status", "pending_verification")
      .eq("is_provisional", true)
      .order("created_at", { ascending: true }),
    client.from("batches").select("id, name, session"),
    client.from("departments").select("id, name, code").order("name"),
  ]);

  const failed = [profiles, batches, departments].find((r) => r.error);
  if (failed?.error) throw failed.error;

  return {
    profiles: (profiles.data ?? []) as PendingProfile[],
    batches: (batches.data ?? []) as BatchRow[],
    departments: (departments.data ?? []) as DepartmentRow[],
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

export function Approvals() {
  const queryClient = useQueryClient();
  const [busyId, setBusyId] = useState<string | null>(null);

  const query = useQuery({
    queryKey: ["provisional-approvals"],
    queryFn: fetchApprovals,
    placeholderData: keepPreviousData,
    staleTime: 30 * 1000,
  });

  const data = query.data;
  const profiles = data?.profiles ?? [];

  const batchById = useMemo(
    () => new Map(data?.batches.map((b) => [b.id, b]) ?? []),
    [data?.batches],
  );
  const departmentById = useMemo(
    () => new Map(data?.departments.map((d) => [d.id, d]) ?? []),
    [data?.departments],
  );

  async function review(profile: PendingProfile, approve: boolean) {
    if (busyId) return;
    if (!approve) {
      const ok = window.confirm(
        `Reject ${profile.full_name}'s registration? Their account will be archived.`,
      );
      if (!ok) return;
    }
    setBusyId(profile.id);
    try {
      const { error } = await client.rpc("review_provisional_account", {
        target_profile_id: profile.id,
        approve,
      });
      if (error) throw error;
      toast.success(
        approve
          ? `${profile.full_name} approved`
          : `${profile.full_name} rejected`,
      );
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["provisional-approvals"] }),
        queryClient.invalidateQueries({ queryKey: ["rows", "profiles"] }),
        queryClient.invalidateQueries({ queryKey: ["dashboard"] }),
      ]);
    } catch (e) {
      toast.error(approve ? "Approval failed" : "Rejection failed", {
        description:
          e instanceof Error ? e.message : "The database rejected the change.",
      });
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      <header>
        <span style={{ fontSize: 12, opacity: 0.7 }}>
          Accounts · identity verification
        </span>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: "4px 0" }}>
          Provisional account approvals
        </h1>
        <p style={{ fontSize: 14, opacity: 0.8, maxWidth: 720 }}>
          New students who registered without a university email land here for
          identity review. Approving activates the account; the student can add
          their <code>@bu.ac.bd</code> email later to become fully verified.
          Batch CRs can also approve their own batchmates from the mobile app.
        </p>
      </header>

      {query.isError ? (
        <div
          style={{
            padding: 16,
            borderRadius: 12,
            border: "1px solid var(--border, #333)",
          }}
        >
          <strong>Could not load approvals</strong>
          <p>
            {query.error instanceof Error
              ? query.error.message
              : "Check the admin session and RLS policies."}
          </p>
          <button onClick={() => query.refetch()} type="button">
            Try again
          </button>
        </div>
      ) : null}

      <section
        style={{
          border: "1px solid var(--border, #2a2a2a)",
          borderRadius: 14,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            padding: "14px 18px",
            borderBottom: "1px solid var(--border, #2a2a2a)",
          }}
        >
          <h2 style={{ fontSize: 16, fontWeight: 600, margin: 0 }}>
            Pending accounts
          </h2>
          <p style={{ fontSize: 13, opacity: 0.7, margin: "2px 0 0" }}>
            {profiles.length.toLocaleString()} awaiting review
          </p>
        </div>

        <div style={{ overflowX: "auto" }}>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr style={{ textAlign: "left", fontSize: 12, opacity: 0.7 }}>
                <th style={{ padding: "10px 18px" }}>Student</th>
                <th style={{ padding: "10px 18px" }}>Department</th>
                <th style={{ padding: "10px 18px" }}>Batch</th>
                <th style={{ padding: "10px 18px" }}>Personal email</th>
                <th style={{ padding: "10px 18px" }} aria-label="Actions" />
              </tr>
            </thead>
            <tbody>
              {query.isLoading ? (
                <tr>
                  <td colSpan={5} style={{ padding: 24, textAlign: "center" }}>
                    Loading…
                  </td>
                </tr>
              ) : profiles.length ? (
                profiles.map((profile) => {
                  const batch = profile.batch_id
                    ? batchById.get(profile.batch_id)
                    : undefined;
                  const department = profile.department_id
                    ? departmentById.get(profile.department_id)
                    : undefined;
                  const busy = busyId === profile.id;
                  return (
                    <tr
                      key={profile.id}
                      style={{ borderTop: "1px solid var(--border, #222)" }}
                    >
                      <td style={{ padding: "12px 18px" }}>
                        <div
                          style={{ display: "flex", alignItems: "center", gap: 10 }}
                        >
                          <span
                            style={{
                              width: 34,
                              height: 34,
                              borderRadius: "50%",
                              background: "#3b82f6",
                              color: "#fff",
                              display: "grid",
                              placeItems: "center",
                              fontSize: 12,
                              fontWeight: 700,
                            }}
                          >
                            {initials(profile.full_name || "?")}
                          </span>
                          <div>
                            <strong style={{ display: "block" }}>
                              {profile.full_name || "Unnamed"}
                            </strong>
                            <small style={{ opacity: 0.7 }}>
                              {profile.student_id || profile.roll || "—"}
                            </small>
                          </div>
                        </div>
                      </td>
                      <td style={{ padding: "12px 18px" }}>
                        {department?.code ?? "—"}
                      </td>
                      <td style={{ padding: "12px 18px" }}>
                        {batch?.name || batch?.session || "No batch"}
                      </td>
                      <td style={{ padding: "12px 18px" }}>
                        {profile.personal_email || profile.email}
                      </td>
                      <td style={{ padding: "12px 18px" }}>
                        <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
                          <button
                            disabled={busy}
                            onClick={() => review(profile, false)}
                            type="button"
                            style={{
                              padding: "6px 12px",
                              borderRadius: 8,
                              border: "1px solid var(--border, #444)",
                              background: "transparent",
                              color: "#ef4444",
                              cursor: busy ? "not-allowed" : "pointer",
                            }}
                          >
                            Reject
                          </button>
                          <button
                            disabled={busy}
                            onClick={() => review(profile, true)}
                            type="button"
                            style={{
                              padding: "6px 12px",
                              borderRadius: 8,
                              border: "none",
                              background: "#16a34a",
                              color: "#fff",
                              cursor: busy ? "not-allowed" : "pointer",
                            }}
                          >
                            {busy ? "Working…" : "Approve"}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              ) : (
                <tr>
                  <td colSpan={5} style={{ padding: 32, textAlign: "center", opacity: 0.7 }}>
                    No accounts are awaiting approval.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
