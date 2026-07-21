import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Students" };

export default function StudentsPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="profiles"
        description="Search every registered student, review identity and academic placement, update profile state, and inspect the privacy-limited directory. CR roles are changed only through the protected CR workflow."
        entityNames={["profiles", "people_directory", "cr_assignments"]}
        eyebrow="People · registered accounts"
        title="Students & accounts"
      />
    </Suspense>
  );
}
