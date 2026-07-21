import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { MfaForm } from "@/components/auth/mfa-form";
import { requireAdmin } from "@/lib/auth/require-admin";
import { safeNextPath } from "@/lib/auth/safe-next-path";

export const metadata: Metadata = {
  title: "Verify identity",
};

export default async function MfaPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string }>;
}) {
  const [identity, params] = await Promise.all([
    requireAdmin({ requireMfa: false }),
    searchParams,
  ]);
  const nextPath = safeNextPath(params.next);

  if (identity.assuranceLevel === "aal2") redirect(nextPath);

  return <MfaForm adminName={identity.profile.fullName} nextPath={nextPath} />;
}
