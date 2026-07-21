"use client";

import {
  createBrowserClient as createSupabaseBrowserClient,
} from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

import { getPublicSupabaseEnvironment } from "./env";

let browserClient: SupabaseClient | undefined;

export function createBrowserClient() {
  if (browserClient) return browserClient;

  const { url, publishableKey } = getPublicSupabaseEnvironment();
  browserClient = createSupabaseBrowserClient(url, publishableKey);
  return browserClient;
}
