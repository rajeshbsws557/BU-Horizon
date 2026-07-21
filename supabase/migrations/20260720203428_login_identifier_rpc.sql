-- BU Horizon — 14. Login-identifier resolution (poll Q22)
-- Supabase Auth signs in by email + password. To also allow login by Student ID,
-- the client calls this RPC first to resolve an identifier (email OR student_id)
-- to the account email, then signs in with that email.
--
-- SECURITY DEFINER so it can read profiles before the user is authenticated.
-- It is deliberately narrow: it takes one identifier, returns at most one email,
-- and only for active, non-deleted accounts. No other columns are exposed.

create or replace function public.resolve_login_email(identifier text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  -- Note: no `::citext` cast here — with search_path = '' the citext type name
  -- would not resolve. Casting the citext column to text and lower()ing both
  -- sides keeps the email match case-insensitive.
  select p.email::text
  from public.profiles p
  where p.status = 'active'
    and p.deleted_at is null
    and (
      lower(p.email::text) = lower(identifier)
      or p.student_id = identifier
    )
  limit 1;
$$;

-- Callable before authentication (login screen), so grant to anon as well.
revoke all on function public.resolve_login_email(text) from public;
grant execute on function public.resolve_login_email(text) to anon, authenticated;

comment on function public.resolve_login_email(text) is
  'Resolves an email or student ID to the account email for login (poll Q22). Returns email only, active accounts only.';
