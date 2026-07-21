import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Academics" };

export default function AcademicsPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="faculties"
        description="Manage the complete faculty-to-batch hierarchy, department course catalogue, and term-specific course offerings used throughout the student app."
        eyebrow="Academic operations"
        groups={["academic"]}
        title="Academic structure"
      />
    </Suspense>
  );
}
