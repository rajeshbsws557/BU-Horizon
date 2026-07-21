import type { Metadata } from "next";

import { CrManagement } from "@/components/cr-management/cr-management";

export const metadata: Metadata = { title: "CR Management" };

export default function CrManagementPage() {
  return <CrManagement />;
}
