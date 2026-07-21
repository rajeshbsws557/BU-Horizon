import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Content" };

export default function ContentPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="notices"
        description="Control schedules, exams, bilingual notice publishing, attachments, read receipts, learning resources, broadcast alerts, and targeted notifications."
        eyebrow="Scheduling · communications"
        groups={["content"]}
        title="Content operations"
      />
    </Suspense>
  );
}
