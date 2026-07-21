import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Attendance" };

export default function AttendancePage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="class_sessions"
        description="Create class sessions, maintain student attendance, process correction requests, and inspect immutable change history and course-level summaries."
        eyebrow="Classes · attendance"
        groups={["attendance"]}
        title="Attendance operations"
      />
    </Suspense>
  );
}
