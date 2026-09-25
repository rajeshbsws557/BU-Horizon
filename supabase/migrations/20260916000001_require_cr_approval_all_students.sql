-- BU Horizon — Require CR approval for ALL new students (not just provisional).
--
-- Previously, students who registered with a @bu.ac.bd email were auto-approved
-- and landed as 'active'. This migration makes every new student registration
-- land as 'pending_verification' until a super admin or the batch CR approves.
-- Adding a university email later still updates the email fields but no longer
-- auto-activates the account.

-- ===========================================================================
-- 1. handle_new_user: ALL students start as pending_verification.
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
  is_student boolean := initial_role = 'student'::public.user_role;
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
    -- Every student needs CR/admin approval before accessing batch content.
    -- Only super admins are auto-active.
    case when is_student then 'pending_verification'::public.profile_status
         else 'active'::public.profile_status end,
    provisional,
    -- Record the personal email only for provisional sign-ups.
    case when provisional then new.email::extensions.citext else null end,
    -- Record the university email if they signed up with one, but the account
    -- still needs CR approval before it becomes active.
    case when not provisional and is_uni_email then new.email::extensions.citext else null end,
    -- No auto-approval for students; approved_at is set by the review RPC.
    case when not is_student then now() else null end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function private.handle_new_user() is
  'Creates a student profile from Auth sign-up metadata (or a super-admin via protected app_metadata). ALL students land as pending_verification for CR/admin approval regardless of email domain; only super admins are auto-active.';

-- ===========================================================================
-- 2. review_provisional_account: remove the is_provisional gate.
-- Any pending_verification student can now be approved/rejected.
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

  -- Only require the account to be pending_verification; no longer gate on
  -- is_provisional so university-email students are also reviewable.
  if target.status <> 'pending_verification'::public.profile_status then
    raise exception using
      errcode = '23514',
      message = 'This account is not awaiting approval.';
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
    update public.profiles
       set status = 'active'::public.profile_status,
           approved_by = actor_id,
           approved_at = now(),
           updated_at = now()
     where id = target_profile_id
     returning * into target;
  else
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
    case when approve then 'account.approved' else 'account.rejected' end,
    'profile',
    target_profile_id,
    jsonb_build_object('status', 'pending_verification'),
    jsonb_build_object('status', target.status::text, 'approved_by', actor_id)
  );

  return target;
end;
$$;

comment on function public.review_provisional_account(uuid, boolean) is
  'Approves (activates) or rejects (archives) a pending_verification account. Callable by an active super admin or the target batch CR; audited. Works for all students regardless of email type.';

-- ===========================================================================
-- 3. sync_university_email: update email fields but do NOT auto-activate.
-- CR approval is mandatory; a university email alone is not sufficient.
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
           -- Do NOT change status: CR approval is mandatory regardless of
           -- email type. A pending_verification account stays pending.
           updated_at = now()
     where id = new.id
       and (is_provisional or university_email is distinct from new.email);
  end if;
  return new;
end;
$$;

comment on function private.sync_university_email() is
  'When a user confirms a new @bu.ac.bd email, mirrors it to the profile and clears the provisional flag, but does NOT auto-activate the account. CR approval remains mandatory.';
