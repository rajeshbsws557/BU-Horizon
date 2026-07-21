import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Workflows" };

export default function WorkflowsPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="batch_change_requests"
        description="Review batch-change and attendance-correction queues, inspect targeted delivery records, and maintain the operational state behind app requests."
        entityNames={[
          "batch_change_requests",
          "attendance_correction_requests",
          "notifications",
        ]}
        eyebrow="Requests · approvals"
        title="Workflow centre"
      />
    </Suspense>
  );
}
