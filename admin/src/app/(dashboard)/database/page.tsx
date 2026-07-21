import type { Metadata } from "next";
import { Suspense } from "react";

import { DatabaseExplorer } from "@/components/data/database-explorer";

export const metadata: Metadata = { title: "Database Explorer" };

export default function DatabasePage() {
  return (
    <Suspense>
      <DatabaseExplorer />
    </Suspense>
  );
}
