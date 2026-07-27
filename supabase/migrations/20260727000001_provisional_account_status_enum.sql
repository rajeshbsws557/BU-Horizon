-- BU Horizon — Provisional-account flow (part 1 of 2): the new status value.
--
-- `alter type ... add value` cannot run in the same transaction that later uses
-- the new value, and the Supabase CLI wraps each migration file in a single
-- transaction. So the enum value is added in its own migration, and the columns,
-- constraints, functions and triggers that depend on it live in the next one
-- (20260727000002_provisional_account_flow.sql).

alter type public.profile_status add value if not exists 'pending_verification';
