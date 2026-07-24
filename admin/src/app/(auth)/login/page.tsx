import type { Metadata } from "next";
import { redirect } from "next/navigation";

import { LoginForm } from "@/components/auth/login-form";
import { safeNextPath } from "@/lib/auth/safe-next-path";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Sign in",
};

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string }>;
}) {
  const params = await searchParams;
  const nextPath = safeNextPath(params.next);

  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (user && !params.error) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("role, status, deleted_at")
        .eq("id", user.id)
        .maybeSingle();

      if (
        profile &&
        profile.role === "super_admin" &&
        profile.status === "active" &&
        profile.deleted_at === null
      ) {
        const { data: assurance } =
          await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
        const currentLevel = assurance?.currentLevel ?? "aal1";

        if (currentLevel === "aal2") {
          redirect(nextPath);
        } else {
          redirect(`/mfa?next=${encodeURIComponent(nextPath)}`);
        }
      }
    }
  } catch {
    // If check fails or not logged in, render the login form cleanly
  }

  return (
    <LoginForm
      nextPath={nextPath}
      initialError={params.error}
    />
  );
}
