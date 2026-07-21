import "server-only";

import { createClient } from "@/lib/supabase/server";

type AuditRow = {
  id: number;
  actor_id: string | null;
  action: string;
  entity_type: string;
  entity_id: string | null;
  created_at: string;
};

export type DashboardAuditItem = AuditRow & {
  actorName: string;
};

export type DashboardData = {
  metrics: {
    activeStudents: number | null;
    classRepresentatives: number | null;
    activeBatches: number | null;
    courses: number | null;
  };
  attention: {
    attendanceCorrections: number | null;
    batchChanges: number | null;
    openBloodRequests: number | null;
    openLostFound: number | null;
  };
  content: {
    publishedNotices: number | null;
    upcomingExams: number | null;
    resources: number | null;
  };
  audit: DashboardAuditItem[];
  healthy: boolean;
  issueCount: number;
};

function valueOrNull(result: { count: number | null; error: unknown }) {
  return result.error ? null : (result.count ?? 0);
}

function dhakaDate() {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Dhaka",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());
  const value = (type: string) =>
    parts.find((part) => part.type === type)?.value ?? "";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

export async function getDashboardData(): Promise<DashboardData> {
  const supabase = await createClient();
  const today = dhakaDate();

  const [
    activeStudents,
    classRepresentatives,
    activeBatches,
    courses,
    attendanceCorrections,
    batchChanges,
    openBloodRequests,
    openLostFound,
    publishedNotices,
    upcomingExams,
    resources,
    auditResult,
  ] = await Promise.all([
    supabase
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "student")
      .eq("status", "active")
      .is("deleted_at", null),
    supabase.from("cr_assignments").select("id", { count: "exact", head: true }),
    supabase
      .from("batches")
      .select("id", { count: "exact", head: true })
      .eq("status", "active"),
    supabase
      .from("courses")
      .select("id", { count: "exact", head: true })
      .is("deleted_at", null),
    supabase
      .from("attendance_correction_requests")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    supabase
      .from("batch_change_requests")
      .select("id", { count: "exact", head: true })
      .eq("status", "pending"),
    supabase
      .from("blood_requests")
      .select("id", { count: "exact", head: true })
      .eq("status", "open"),
    supabase
      .from("lost_found_items")
      .select("id", { count: "exact", head: true })
      .eq("status", "open"),
    supabase
      .from("notices")
      .select("id", { count: "exact", head: true })
      .eq("state", "published")
      .is("deleted_at", null),
    supabase
      .from("exams")
      .select("id", { count: "exact", head: true })
      .gte("exam_date", today)
      .is("deleted_at", null),
    supabase
      .from("resources")
      .select("id", { count: "exact", head: true })
      .is("deleted_at", null),
    supabase
      .from("audit_logs")
      .select("id, actor_id, action, entity_type, entity_id, created_at")
      .order("created_at", { ascending: false })
      .limit(7),
  ]);

  const countResults = [
    activeStudents,
    classRepresentatives,
    activeBatches,
    courses,
    attendanceCorrections,
    batchChanges,
    openBloodRequests,
    openLostFound,
    publishedNotices,
    upcomingExams,
    resources,
  ];

  const auditRows = auditResult.error
    ? []
    : ((auditResult.data ?? []) as AuditRow[]);
  const actorIds = [
    ...new Set(auditRows.map((row) => row.actor_id).filter((id): id is string => !!id)),
  ];
  let actorNames = new Map<string, string>();
  let actorLookupFailed = false;

  if (actorIds.length) {
    const { data: actors, error: actorsError } = await supabase
      .from("profiles")
      .select("id, full_name")
      .in("id", actorIds);
    actorLookupFailed = Boolean(actorsError);
    if (!actorsError) {
      actorNames = new Map(
        (actors ?? []).map((actor) => [
          actor.id as string,
          (actor.full_name as string) || "Administrator",
        ]),
      );
    }
  }

  const issueCount =
    countResults.filter((result) => Boolean(result.error)).length +
    (auditResult.error ? 1 : 0) +
    (actorLookupFailed ? 1 : 0);

  return {
    metrics: {
      activeStudents: valueOrNull(activeStudents),
      classRepresentatives: valueOrNull(classRepresentatives),
      activeBatches: valueOrNull(activeBatches),
      courses: valueOrNull(courses),
    },
    attention: {
      attendanceCorrections: valueOrNull(attendanceCorrections),
      batchChanges: valueOrNull(batchChanges),
      openBloodRequests: valueOrNull(openBloodRequests),
      openLostFound: valueOrNull(openLostFound),
    },
    content: {
      publishedNotices: valueOrNull(publishedNotices),
      upcomingExams: valueOrNull(upcomingExams),
      resources: valueOrNull(resources),
    },
    audit: auditRows.map((row) => ({
      ...row,
      actorName: row.actor_id
        ? (actorNames.get(row.actor_id) ?? "Administrator")
        : "System",
    })),
    healthy: issueCount === 0,
    issueCount,
  };
}
