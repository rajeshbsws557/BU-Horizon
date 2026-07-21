import "server-only";

import { createClient as createSupabaseClient } from "@supabase/supabase-js";

import { getPublicSupabaseEnvironment } from "./env";

/**
 * Server-only service-role client for narrow Auth Admin operations.
 *
 * Ordinary dashboard reads and writes must use `server.ts` so the signed-in
 * administrator's JWT and database RLS remain the primary authorization layer.
 */
export function createAdminClient() {
  const { url } = getPublicSupabaseEnvironment();
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!serviceRoleKey) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY is not configured on the server.");
  }

  return createSupabaseClient(url, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
