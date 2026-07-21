import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Audit Log" };

export default function AuditPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="audit_logs"
        description="Review the append-only record of privileged operations. Audit rows cannot be edited or deleted, including by a super administrator."
        entityNames={["audit_logs"]}
        eyebrow="Security · immutable history"
        title="Audit log"
      />
    </Suspense>
  );
}
