import "server-only";

import type { User } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { cache } from "react";

import { createClient } from "@/lib/supabase/server";

type ProfileRow = {
  id: string;
  full_name: string;
  email: string;
  role: string;
  status: string;
  avatar_url: string | null;
  deleted_at: string | null;
};

export type AdminIdentity = {
  user: User;
  profile: {
    id: string;
    fullName: string;
    email: string;
    avatarUrl: string | null;
  };
  assuranceLevel: "aal1" | "aal2" | null;
};

export const requireAdmin = cache(async function requireAdmin(
  options?: { requireMfa?: boolean },
) {
  const requireMfa = options?.requireMfa ?? true;
  const supabase = await createClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) redirect("/login?error=session");

  const { data, error: profileError } = await supabase
    .from("profiles")
    .select("id, full_name, email, role, status, avatar_url, deleted_at")
    .eq("id", user.id)
    .maybeSingle();

  const profile = data as ProfileRow | null;
  const isActiveAdmin =
    !profileError &&
    profile?.role === "super_admin" &&
    profile.status === "active" &&
    profile.deleted_at === null;

  if (!isActiveAdmin) redirect("/login?error=not-authorized");

  const { data: assurance, error: assuranceError } =
    await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  const currentLevel = (assurance?.currentLevel ?? null) as string | null;
  const assuranceLevel: "aal1" | "aal2" | null =
    !assuranceError && (currentLevel === "aal1" || currentLevel === "aal2")
      ? currentLevel
      : null;

  if (requireMfa && assuranceLevel !== "aal2") redirect("/mfa");

  return {
    user,
    profile: {
      id: profile.id,
      fullName: profile.full_name,
      email: profile.email,
      avatarUrl: profile.avatar_url,
    },
    assuranceLevel,
  } satisfies AdminIdentity;
});
