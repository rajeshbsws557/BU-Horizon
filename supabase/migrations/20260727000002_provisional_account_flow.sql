-- BU Horizon — Provisional-account flow (part 2 of 2).
--
-- Newly admitted students do not receive their @bu.ac.bd email for ~6 months.
-- This lets them register with a personal email, land in a
-- `pending_verification` state (added in part 1), be approved by a super admin
-- OR their batch CR, and later self-promote to a fully verified account once
-- the university email is issued and confirmed.

-- ===========================================================================
-- 1. Provisional-account profile columns.
-- ===========================================================================
alter table public.profiles
  add column if not exists is_provisional boolean not null default false,
  add column if not exists personal_email extensions.citext,
  add column if not exists university_email extensions.citext,
  add column if not exists approved_by uuid references public.profiles (id) on delete set null,
  add column if not exists approved_at timestamptz;

comment on column public.profiles.is_provisional is
  'True when the student registered without a @bu.ac.bd email and identity is gated by admin/CR approval instead of the email domain.';
comment on column public.profiles.personal_email is
  'The personal email a provisional student registered with (before their university email is issued).';
comment on column public.profiles.university_email is
  'The verified @bu.ac.bd address once issued and confirmed. When set, the account is fully verified.';
comment on column public.profiles.approved_by is
  'Super admin or batch CR who approved a provisional account.';
comment on column public.profiles.approved_at is
  'When the provisional account identity was approved.';

-- ===========================================================================
-- 2. Relax the university-email domain constraint.
-- The invariant becomes: account is @bu.ac.bd, OR is a super_admin using any
-- valid email (external-admin exception, preserved), OR is provisional.
-- ===========================================================================
alter table public.profiles drop constraint if exists chk_email_domain;
alter table public.profiles
  add constraint chk_email_domain check (
    email ~* '^[^@\s]+@bu\.ac\.bd$'
    or is_provisional
    or (
      role = 'super_admin'::public.user_role
      and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    )
  );

-- A verified university_email, when present, must be a real @bu.ac.bd address.
alter table public.profiles drop constraint if exists chk_university_email_domain;
alter table public.profiles
  add constraint chk_university_email_domain check (
    university_email is null or university_email ~* '^[^@\s]+@bu\.ac\.bd$'
  );

create index if not exists idx_profiles_is_provisional
  on public.profiles (is_provisional) where is_provisional;

-- ===========================================================================
-- 3. handle_new_user: honour the is_provisional sign-up flag while keeping the
-- protected super-admin bootstrap (role from Auth app_metadata).
-- ===========================================================================
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  initial_role public.user_role := case
    when new.raw_app_meta_data->>'role' = 'super_admin'
      then 'super_admin'::public.user_role
    else 'student'::public.user_role
  end;
  provisional boolean := coalesce(
    (new.raw_user_meta_data->>'is_provisional')::boolean, false
  ) and initial_role = 'student'::public.user_role;
  is_uni_email boolean := new.email ~* '^[^@\s]+@bu\.ac\.bd$';
begin
  insert into public.profiles (
    id, role, email, full_name, roll, student_id, phone,
    faculty_id, department_id, batch_id,
    academic_system, current_term,
    status, is_provisional, personal_email, university_email, approved_at
  )
  values (
    new.id,
    initial_role,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.raw_user_meta_data->>'roll',
    new.raw_user_meta_data->>'student_id',
    new.raw_user_meta_data->>'phone',
    nullif(new.raw_user_meta_data->>'faculty_id','')::uuid,
    nullif(new.raw_user_meta_data->>'department_id','')::uuid,
    nullif(new.raw_user_meta_data->>'batch_id','')::uuid,
    nullif(new.raw_user_meta_data->>'academic_system','')::public.academic_system,
    nullif(new.raw_user_meta_data->>'current_term','')::smallint,
    -- A provisional (non-university-email) sign-up is gated by approval.
    case when provisional then 'pending_verification'::public.profile_status
         else 'active'::public.profile_status end,
    provisional,
    -- Record the personal email only for provisional sign-ups.
    case when provisional then new.email::extensions.citext else null end,
    -- A student who signed up directly with a university email is verified.
    case when not provisional and is_uni_email then new.email::extensions.citext else null end,
    case when not provisional then now() else null end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function private.handle_new_user() is
  'Creates a student profile from Auth sign-up metadata (or a super-admin via protected app_metadata). A provisional (no @bu.ac.bd email) student lands as pending_verification for admin/CR approval; otherwise the account is auto-approved and active.';

-- ===========================================================================
-- 4. Allow pending_verification accounts to sign in.
-- They need to log in to see their approval status and later add a university
-- email. Feature access is still gated by their status in the app/RLS.
-- ===========================================================================
create or replace function public.resolve_login_email(identifier text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.email::text
  from public.profiles p
  where p.status in ('active'::public.profile_status,
                     'pending_verification'::public.profile_status)
    and p.deleted_at is null
    and (
      lower(p.email::text) = lower(identifier)
      or p.student_id = identifier
    )
  limit 1;
$$;

revoke all on function public.resolve_login_email(text) from public;
grant execute on function public.resolve_login_email(text) to anon, authenticated;

comment on function public.resolve_login_email(text) is
  'Resolves an email or student ID to the account email for login (poll Q22). Returns email only, for active or pending-verification accounts.';

-- ===========================================================================
-- 5. Approve / reject a provisional account.
-- Authorization: an active AAL2 super admin, OR an active CR of the target's
-- batch. A CR may only approve/reject their own batchmates (fresher-batch CR
-- vouching, per the requested design). Every decision is audited.
-- ===========================================================================
create or replace function public.review_provisional_account(
  target_profile_id uuid,
  approve boolean
)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  target public.profiles%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'Authentication required.';
  end if;
  if target_profile_id is null then
    raise exception using errcode = '22004', message = 'target_profile_id is required.';
  end if;
  if approve is null then
    raise exception using errcode = '22004', message = 'approve is required.';
  end if;

  select p.* into target
    from public.profiles p
   where p.id = target_profile_id
   for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'Target profile was not found.';
  end if;

  if not target.is_provisional
     or target.status <> 'pending_verification'::public.profile_status then
    raise exception using
      errcode = '23514',
      message = 'This account is not awaiting provisional approval.';
  end if;

  -- Only a super admin or an active CR of the same batch may decide.
  if not (
    private.is_super_admin()
    or (target.batch_id is not null and private.is_cr_of_batch(target.batch_id))
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only a super admin or the batch CR can review this account.';
  end if;

  if approve then
    -- Identity vouched: activate the account. It remains provisional (personal
    -- email) until a university email is added and verified.
    update public.profiles
       set status = 'active'::public.profile_status,
           approved_by = actor_id,
           approved_at = now(),
           updated_at = now()
     where id = target_profile_id
     returning * into target;
  else
    -- Rejected: archive the profile so it no longer occupies the queue. The
    -- Auth user still exists; a super admin can hard-delete if required.
    update public.profiles
       set status = 'archived'::public.profile_status,
           approved_by = actor_id,
           approved_at = now(),
           updated_at = now()
     where id = target_profile_id
     returning * into target;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, old_data, new_data)
  values (
    actor_id,
    case when approve then 'provisional.approved' else 'provisional.rejected' end,
    'profile',
    target_profile_id,
    jsonb_build_object('status', 'pending_verification'),
    jsonb_build_object('status', target.status::text, 'approved_by', actor_id)
  );

  return target;
end;
$$;

revoke all on function public.review_provisional_account(uuid, boolean) from public, anon;
grant execute on function public.review_provisional_account(uuid, boolean) to authenticated;

comment on function public.review_provisional_account(uuid, boolean) is
  'Approves (activates) or rejects (archives) a pending_verification provisional account. Callable by an active super admin or the target batch CR; audited.';

-- ===========================================================================
-- 6. Promote a provisional account to fully verified once the university email
-- is confirmed. Runs from an auth.users email-change: when the new address is
-- @bu.ac.bd, mirror it onto the profile and clear the provisional flag.
-- ===========================================================================
create or replace function private.sync_university_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email is distinct from old.email
     and new.email ~* '^[^@\s]+@bu\.ac\.bd$' then
    update public.profiles
       set email = new.email,
           university_email = new.email,
           is_provisional = false,
           -- A confirmed university email is strong identity proof: a still
           -- pending account becomes active and self-approved.
           status = case
             when status = 'pending_verification'::public.profile_status
               then 'active'::public.profile_status
             else status
           end,
           approved_at = coalesce(approved_at, now()),
           updated_at = now()
     where id = new.id
       and (is_provisional or university_email is distinct from new.email);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_auth_user_email_synced on auth.users;
create trigger trg_auth_user_email_synced
  after update of email on auth.users
  for each row execute function private.sync_university_email();

comment on function private.sync_university_email() is
  'When a user confirms a new @bu.ac.bd email, mirrors it to the profile and promotes a provisional account to fully verified.';
