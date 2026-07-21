import type { Metadata } from "next";

import { DashboardView } from "@/components/dashboard/dashboard-view";
import { getDashboardData } from "@/features/dashboard/dashboard-data";
import { requireAdmin } from "@/lib/auth/require-admin";

export const metadata: Metadata = {
  title: "Dashboard",
};

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const [{ profile }, data] = await Promise.all([
    requireAdmin(),
    getDashboardData(),
  ]);

  return <DashboardView data={data} adminName={profile.fullName} />;
}
