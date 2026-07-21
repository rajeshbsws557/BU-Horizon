import type { Metadata } from "next";
import { Suspense } from "react";

import { SectionWorkspace } from "@/components/data/section-workspace";

export const metadata: Metadata = { title: "Campus Services" };

export default function CampusPage() {
  return (
    <Suspense>
      <SectionWorkspace
        defaultEntity="bus_routes"
        description="Maintain the live bus timetable, moderate blood-help requests and donor listings, and manage lost-and-found reports with their private responses."
        eyebrow="University services"
        groups={["campus"]}
        title="Campus services"
      />
    </Suspense>
  );
}
