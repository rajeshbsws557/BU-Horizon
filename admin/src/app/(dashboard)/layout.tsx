import type { ReactNode } from "react";

import { AdminShell } from "@/components/layout/admin-shell";
import { requireAdmin } from "@/lib/auth/require-admin";

export default async function DashboardLayout({ children }: { children: ReactNode }) {
  const { profile } = await requireAdmin();

  return (
    <AdminShell admin={{ fullName: profile.fullName, email: profile.email }}>
      {children}
    </AdminShell>
  );
}
