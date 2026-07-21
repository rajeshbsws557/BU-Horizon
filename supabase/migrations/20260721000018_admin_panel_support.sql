-- BU Horizon — 18. Admin panel support
--
-- Adds the two narrow SECURITY DEFINER entry points required by the admin
-- panel, hardens the role helpers used by RLS, and fills the remaining
-- super-admin policy gaps on operational/user-authored data. Immutable audit
-- and attendance history, plus derived views, intentionally remain read-only.

-- ---------------------------------------------------------------------------
-- Active-role authorization helpers
-- ---------------------------------------------------------------------------
-- Suspended, archived, soft-deleted, or batch-mismatched accounts must not
-- retain privileged access merely because an old role/assignment row remains.

create or replace function private.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'super_admin'::public.user_role
      and p.status = 'active'::public.profile_status
      and p.deleted_at is null
      -- The website requires TOTP/AAL2, and the database enforces the same
      -- boundary so an AAL1 token cannot bypass the panel via direct REST/RPC.
      and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
  );
$$;

create or replace function private.is_cr_of_batch(target_batch uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.cr_assignments ca
    join public.profiles p on p.id = ca.profile_id
    where ca.profile_id = (select auth.uid())
      and ca.batch_id = target_batch
      and p.batch_id = ca.batch_id
      and p.role = 'cr'::public.user_role
      and p.status = 'active'::public.profile_status
      and p.deleted_at is null
  );
$$;

create or replace function private.is_cr_of_department(target_department uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.cr_assignments ca
    join public.profiles pr on pr.id = ca.profile_id
    join public.batches b on b.id = ca.batch_id
    join public.programs p on p.id = b.program_id
    where ca.profile_id = (select auth.uid())
      and pr.batch_id = ca.batch_id
      and pr.role = 'cr'::public.user_role
      and pr.status = 'active'::public.profile_status
      and pr.deleted_at is null
      and p.department_id = target_department
  );
$$;

revoke all on function private.is_super_admin() from public;
revoke all on function private.is_super_admin() from anon;
revoke all on function private.is_cr_of_batch(uuid) from public;
revoke all on function private.is_cr_of_batch(uuid) from anon;
revoke all on function private.is_cr_of_department(uuid) from public;
revoke all on function private.is_cr_of_department(uuid) from anon;
grant execute on function private.is_super_admin() to authenticated;
grant execute on function private.is_cr_of_batch(uuid) to authenticated;
grant execute on function private.is_cr_of_department(uuid) to authenticated;

-- A CR role and its assignment are one invariant. Super admins retain broad
-- profile editing, but browser clients may not mutate the role column directly;
-- admin_set_cr opens this transaction-local gate for its atomic update. SQL
-- editor/service maintenance has no auth.uid() and remains available for the
-- initial super-admin bootstrap.
create or replace function private.guard_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and coalesce(
       pg_catalog.current_setting('app.admin_set_cr', true),
       'off'
     ) <> 'on'
     and (
       (tg_op = 'INSERT' and new.role <> 'student'::public.user_role)
       or (tg_op = 'UPDATE' and new.role is distinct from old.role)
     ) then
    raise exception using
      errcode = '42501',
      message = 'Profile roles must be changed through the protected admin role workflow.';
  end if;
  return new;
end;
$$;

revoke all on function private.guard_profile_role_change()
  from public, anon, authenticated;

drop trigger if exists trg_profiles_guard_role_change on public.profiles;
create trigger trg_profiles_guard_role_change
  before insert or update of role on public.profiles
  for each row execute function private.guard_profile_role_change();

-- The original cap trigger only counted rows. Two concurrent inserts could
-- both observe a free slot, and UPDATE of an assignment was not checked at all.
-- Lock the target profile first (one assignment per person) and then the batch
-- (two assignments per batch), matching admin_set_cr's lock order.
create or replace function private.enforce_cr_cap()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  batch_assignment_count integer;
begin
  perform 1
    from public.profiles p
   where p.id = new.profile_id
   for update;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The CR assignment profile does not exist.';
  end if;

  perform 1
    from public.batches b
   where b.id = new.batch_id
   for update;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The CR assignment batch does not exist.';
  end if;

  if exists (
    select 1
    from public.cr_assignments ca
    where ca.profile_id = new.profile_id
      and ca.id is distinct from new.id
  ) then
    raise exception using
      errcode = '23505',
      message = 'A profile can have only one active CR assignment.';
  end if;

  select count(*)::integer
    into batch_assignment_count
    from public.cr_assignments ca
   where ca.batch_id = new.batch_id
     and ca.id is distinct from new.id;

  if batch_assignment_count >= 2 then
    raise exception using
      errcode = '23514',
      message = 'A batch can have at most two class representatives.';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_cr_cap()
  from public, anon, authenticated;

drop trigger if exists trg_cr_cap on public.cr_assignments;
create trigger trg_cr_cap
  before insert or update of batch_id, profile_id on public.cr_assignments
  for each row execute function private.enforce_cr_cap();

-- ---------------------------------------------------------------------------
-- Atomic CR promotion / unpromotion
-- ---------------------------------------------------------------------------
-- A CR is represented by BOTH profiles.role and one same-batch assignment.
-- This function is the supported admin mutation path so those two records do
-- not drift. A PostgreSQL function call is one transaction: any exception,
-- including an audit failure or postcondition failure, rolls the whole change
-- back.

create or replace function public.admin_set_cr(
  target_profile_id uuid,
  promote boolean,
  target_batch_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id                 uuid := (select auth.uid());
  target_profile           public.profiles%rowtype;
  effective_batch_id       uuid;
  old_role                 public.user_role;
  assignment_id            uuid;
  assignment_batch_id      uuid;
  assignment_count         integer := 0;
  matching_assignment_count integer := 0;
  batch_cr_count            integer := 0;
  remaining_assignments     integer := 0;
  changed                   boolean := false;
  audit_id                  bigint;
begin
  if actor_id is null or not private.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only an active super admin can promote or unpromote a CR.';
  end if;

  if target_profile_id is null then
    raise exception using
      errcode = '22004',
      message = 'target_profile_id is required.';
  end if;

  if promote is null then
    raise exception using
      errcode = '22004',
      message = 'promote is required.';
  end if;

  if target_profile_id = actor_id then
    raise exception using
      errcode = '42501',
      message = 'A super admin cannot change their own role through admin_set_cr.';
  end if;

  -- Serializes concurrent operations for this account and gives us a stable
  -- role/batch/status snapshot.
  select p.*
    into target_profile
    from public.profiles p
   where p.id = target_profile_id
   for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Target profile was not found.';
  end if;

  if target_profile.role not in (
    'student'::public.user_role,
    'cr'::public.user_role
  ) then
    raise exception using
      errcode = '23514',
      message = 'The target must be a student or CR; super-admin accounts cannot be changed here.';
  end if;

  old_role := target_profile.role;

  -- Opens the role-guard trigger only for this transaction. The function has
  -- already authenticated an active AAL2 super admin above.
  perform pg_catalog.set_config('app.admin_set_cr', 'on', true);

  -- Lock existing assignments before deciding which batch an unpromotion must
  -- clean. Promotion remains strictly tied to profiles.batch_id below.
  perform 1
    from public.cr_assignments ca
   where ca.profile_id = target_profile_id
   for update;

  select count(*)::integer
    into assignment_count
    from public.cr_assignments ca
   where ca.profile_id = target_profile_id;

  if assignment_count = 1 then
    select ca.id, ca.batch_id
      into assignment_id, assignment_batch_id
      from public.cr_assignments ca
     where ca.profile_id = target_profile_id;
  end if;

  if promote then
    -- Promotion must not guess which cross-batch legacy appointment is
    -- authoritative. Unpromotion below is different: its postcondition is
    -- unambiguous, so it removes every assignment owned by the profile.
    if assignment_count > 1 then
      raise exception using
        errcode = '23514',
        message = 'The profile has multiple CR assignments; unpromote it to clean them before promoting it again.';
    end if;

    if target_profile.status <> 'active'::public.profile_status
       or target_profile.deleted_at is not null then
      raise exception using
        errcode = '23514',
        message = 'Only an active, non-deleted profile can be promoted to CR.';
    end if;

    if target_profile.batch_id is null then
      raise exception using
        errcode = '23502',
        message = 'The target profile must belong to a batch before promotion.';
    end if;

    if target_batch_id is not null
       and target_batch_id is distinct from target_profile.batch_id then
      raise exception using
        errcode = '23514',
        message = 'A CR can only be assigned to their own profile batch.';
    end if;

    effective_batch_id := target_profile.batch_id;

    if assignment_count = 1
       and assignment_batch_id is distinct from effective_batch_id then
      raise exception using
        errcode = '23514',
        message = 'The profile has a cross-batch CR assignment; repair it before promotion.';
    end if;

    matching_assignment_count := assignment_count;
  else
    -- Unpromotion is deliberately cleanup-friendly: an inactive/deleted CR or
    -- a profile whose batch drifted can still be made non-privileged. A sole
    -- assignment is unambiguous and takes precedence over profiles.batch_id.
    if assignment_count = 1 then
      effective_batch_id := assignment_batch_id;
      matching_assignment_count := 1;
    else
      effective_batch_id := target_profile.batch_id;
      matching_assignment_count := 0;
    end if;
  end if;

  -- Locking the relevant batch serializes cap checks for different students
  -- in the same batch. A role-only stale CR may have no batch left; it can still
  -- be safely unpromoted without acquiring a batch lock.
  if effective_batch_id is not null then
    perform 1
      from public.batches b
     where b.id = effective_batch_id
     for update;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The relevant CR batch no longer exists.';
    end if;
  end if;

  if promote then
    select count(*)::integer
      into batch_cr_count
      from public.cr_assignments ca
     where ca.batch_id = effective_batch_id;

    -- If this profile already owns the matching row, it contributes one slot;
    -- otherwise promotion needs a new slot. Also refuse to repair a role while
    -- a legacy over-cap state exists.
    if batch_cr_count > 2
       or (matching_assignment_count = 0 and batch_cr_count >= 2) then
      raise exception using
        errcode = '23514',
        message = 'This batch already has the maximum of two class representatives.';
    end if;

    -- Existing matching assignments are retained, allowing this call to repair
    -- an earlier role-only failure without creating a duplicate assignment.
    if matching_assignment_count = 0 then
      insert into public.cr_assignments (batch_id, profile_id, assigned_by)
      values (effective_batch_id, target_profile_id, actor_id)
      returning id into assignment_id;

      changed := true;
    end if;

    if target_profile.role <> 'cr'::public.user_role then
      update public.profiles
         set role = 'cr'::public.user_role,
             updated_at = now()
       where id = target_profile_id;
      changed := true;
    end if;

    select count(*)::integer
      into remaining_assignments
      from public.cr_assignments ca
     where ca.profile_id = target_profile_id
       and ca.batch_id = effective_batch_id;

    if remaining_assignments <> 1
       or not exists (
         select 1
         from public.profiles p
         where p.id = target_profile_id
           and p.role = 'cr'::public.user_role
           and p.batch_id = effective_batch_id
           and p.status = 'active'::public.profile_status
           and p.deleted_at is null
       ) then
      raise exception using
        errcode = '23514',
        message = 'CR promotion postcondition failed; no changes were committed.';
    end if;
  else
    if assignment_count > 0 then
      delete from public.cr_assignments ca
       where ca.profile_id = target_profile_id;
      changed := true;
    end if;

    select count(*)::integer
      into remaining_assignments
      from public.cr_assignments ca
     where ca.profile_id = target_profile_id;

    if remaining_assignments <> 0 then
      raise exception using
        errcode = '23514',
        message = 'CR unpromotion left another assignment; no changes were committed.';
    end if;

    if target_profile.role <> 'student'::public.user_role then
      update public.profiles
         set role = 'student'::public.user_role,
             updated_at = now()
       where id = target_profile_id;
      changed := true;
    end if;

    if not exists (
      select 1
      from public.profiles p
      where p.id = target_profile_id
        and p.role = 'student'::public.user_role
    ) then
      raise exception using
        errcode = '23514',
        message = 'CR unpromotion postcondition failed; no changes were committed.';
    end if;
  end if;

  -- Audit every successful request. Idempotent calls are distinguished from
  -- mutations instead of pretending a role change occurred.
  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data,
    metadata
  )
  values (
    actor_id,
    case
      when promote and changed then 'cr.promoted'
      when promote then 'cr.promotion_verified'
      when changed then 'cr.unpromoted'
      else 'cr.unpromotion_verified'
    end,
    'profile',
    target_profile_id,
    jsonb_build_object(
      'role', old_role::text,
      'assignment_count', assignment_count,
      'profile_batch_id', target_profile.batch_id,
      'assignment_batch_id', assignment_batch_id,
      'profile_status', target_profile.status::text,
      'deleted_at', target_profile.deleted_at
    ),
    jsonb_build_object(
      'role', case when promote then 'cr' else 'student' end,
      'assignment_count', case when promote then 1 else 0 end
    ),
    jsonb_build_object(
      'batch_id', effective_batch_id,
      'requested_batch_id', target_batch_id,
      'assignment_id', assignment_id,
      'changed', changed,
      'source', 'admin_panel'
    )
  )
  returning id into audit_id;

  return jsonb_build_object(
    'profile_id', target_profile_id,
    'batch_id', effective_batch_id,
    'role', case when promote then 'cr' else 'student' end,
    'assignment_id', case when promote then assignment_id else null end,
    'changed', changed,
    'audit_id', audit_id
  );
end;
$$;

revoke all on function public.admin_set_cr(uuid, boolean, uuid) from public;
revoke all on function public.admin_set_cr(uuid, boolean, uuid) from anon;
grant execute on function public.admin_set_cr(uuid, boolean, uuid) to authenticated;

comment on function public.admin_set_cr(uuid, boolean, uuid) is
  'Atomically promotes an active student in their own batch or safely removes a stale/inactive CR, keeps role and assignments consistent, and audits the operation.';

-- Validate the role/assignment pair at transaction end. Deferral lets
-- admin_set_cr insert/delete the assignment and update the role in either order,
-- while still rejecting a committed half-change from service/maintenance code.
create or replace function private.assert_cr_assignment_invariant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_profile_ids uuid[];
  affected_profile_id uuid;
  profile_role public.user_role;
  profile_batch_id uuid;
  profile_exists boolean;
  assignment_count integer;
  matching_assignment_count integer;
begin
  if tg_table_name = 'cr_assignments' then
    if tg_op = 'INSERT' then
      affected_profile_ids := array[new.profile_id];
    elsif tg_op = 'DELETE' then
      affected_profile_ids := array[old.profile_id];
    else
      affected_profile_ids := array[old.profile_id, new.profile_id];
    end if;
  else
    -- `NEW` is unassigned for DELETE triggers (and `OLD` for INSERT), so do
    -- not dereference both records through COALESCE here.
    if tg_op = 'DELETE' then
      affected_profile_ids := array[old.id];
    else
      affected_profile_ids := array[new.id];
    end if;
  end if;

  foreach affected_profile_id in array affected_profile_ids
  loop
    continue when affected_profile_id is null;

    select p.role, p.batch_id
      into profile_role, profile_batch_id
      from public.profiles p
     where p.id = affected_profile_id;

    profile_exists := found;

    select
      count(*)::integer,
      count(*) filter (where ca.batch_id = profile_batch_id)::integer
      into assignment_count, matching_assignment_count
      from public.cr_assignments ca
     where ca.profile_id = affected_profile_id;

    if profile_exists and profile_role = 'cr'::public.user_role then
      if profile_batch_id is null
         or assignment_count <> 1
         or matching_assignment_count <> 1 then
        raise exception using
          errcode = '23514',
          message = 'A CR profile must have exactly one assignment in its own batch.';
      end if;
    elsif assignment_count <> 0 then
      raise exception using
        errcode = '23514',
        message = 'Only a CR profile may own a CR assignment.';
    end if;
  end loop;

  return null;
end;
$$;

revoke all on function private.assert_cr_assignment_invariant()
  from public, anon, authenticated;

drop trigger if exists trg_cr_invariant_assignments on public.cr_assignments;
create constraint trigger trg_cr_invariant_assignments
  after insert or update or delete on public.cr_assignments
  deferrable initially deferred
  for each row execute function private.assert_cr_assignment_invariant();

drop trigger if exists trg_cr_invariant_profile_insert_delete on public.profiles;
create constraint trigger trg_cr_invariant_profile_insert_delete
  after insert or delete on public.profiles
  deferrable initially deferred
  for each row execute function private.assert_cr_assignment_invariant();

drop trigger if exists trg_cr_invariant_profile_update on public.profiles;
create constraint trigger trg_cr_invariant_profile_update
  after update of role, batch_id on public.profiles
  deferrable initially deferred
  for each row execute function private.assert_cr_assignment_invariant();

-- Denormalized batch ids are authorization keys in RLS, so they must agree
-- with their parent rows. Foreign keys alone only prove that both ids exist.
create or replace function private.validate_academic_relationships()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  parent_batch_id uuid;
  parent_department_id uuid;
  batch_department_id uuid;
  student_batch_id uuid;
  record_session_id uuid;
  record_student_id uuid;
  record_batch_id uuid;
begin
  -- Reference-table reparenting can otherwise invalidate an existing
  -- offering without touching that offering row, so validate those changes
  -- at the source as well as validating child inserts/updates below.
  if tg_table_name = 'courses' then
    if exists (
      select 1
      from public.course_offerings co
      join public.batches b on b.id = co.batch_id
      join public.programs p on p.id = b.program_id
      where co.course_id = new.id
        and p.department_id is distinct from new.department_id
    ) then
      raise exception using
        errcode = '23514',
        message = 'Move or remove incompatible course offerings before changing a course department.';
    end if;

  elsif tg_table_name = 'batches' then
    if exists (
      select 1
      from public.course_offerings co
      join public.courses c on c.id = co.course_id
      join public.programs p on p.id = new.program_id
      where co.batch_id = new.id
        and c.department_id is distinct from p.department_id
    ) then
      raise exception using
        errcode = '23514',
        message = 'Move or remove incompatible course offerings before changing a batch program.';
    end if;

  elsif tg_table_name = 'programs' then
    if exists (
      select 1
      from public.batches b
      join public.course_offerings co on co.batch_id = b.id
      join public.courses c on c.id = co.course_id
      where b.program_id = new.id
        and c.department_id is distinct from new.department_id
    ) then
      raise exception using
        errcode = '23514',
        message = 'Move or remove incompatible course offerings before changing a program department.';
    end if;

  elsif tg_table_name = 'course_offerings' then
    select c.department_id, p.department_id
      into parent_department_id, batch_department_id
      from public.courses c
      cross join public.batches b
      join public.programs p on p.id = b.program_id
     where c.id = new.course_id
       and b.id = new.batch_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The course offering course or batch does not exist.';
    end if;

    if parent_department_id is distinct from batch_department_id then
      raise exception using
        errcode = '23514',
        message = 'A course offering course must belong to the batch department.';
    end if;

    if tg_op = 'UPDATE'
       and new.batch_id is distinct from old.batch_id
       and (
         exists (select 1 from public.class_sessions x where x.offering_id = old.id)
         or exists (select 1 from public.class_schedules x where x.offering_id = old.id)
         or exists (select 1 from public.exams x where x.offering_id = old.id)
         or exists (select 1 from public.resources x where x.offering_id = old.id)
       ) then
      raise exception using
        errcode = '23514',
        message = 'Move or remove offering dependants before changing its batch.';
    end if;

  elsif tg_table_name = 'class_sessions' then
    select co.batch_id
      into parent_batch_id
      from public.course_offerings co
     where co.id = new.offering_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The class session offering does not exist.';
    end if;

    if parent_batch_id is distinct from new.batch_id then
      raise exception using
        errcode = '23514',
        message = 'A class session must use its offering batch.';
    end if;

    if tg_op = 'UPDATE'
       and (
         new.batch_id is distinct from old.batch_id
         or new.offering_id is distinct from old.offering_id
       )
       and (
         exists (select 1 from public.attendance_records x where x.session_id = old.id)
         or exists (
           select 1
           from public.attendance_correction_requests x
           where x.session_id = old.id
         )
       ) then
      raise exception using
        errcode = '23514',
        message = 'Move or remove attendance dependants before changing the session offering or batch.';
    end if;

  elsif tg_table_name = 'attendance_records' then
    select cs.batch_id
      into parent_batch_id
      from public.class_sessions cs
     where cs.id = new.session_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The attendance class session does not exist.';
    end if;

    if parent_batch_id is distinct from new.batch_id then
      raise exception using
        errcode = '23514',
        message = 'An attendance record must use its class session batch.';
    end if;

    if tg_op = 'INSERT'
       or new.student_id is distinct from old.student_id
       or new.batch_id is distinct from old.batch_id then
      select p.batch_id
        into student_batch_id
        from public.profiles p
       where p.id = new.student_id;

      if not found then
        raise exception using
          errcode = '23503',
          message = 'The attendance student profile does not exist.';
      end if;

      if student_batch_id is distinct from new.batch_id then
        raise exception using
          errcode = '23514',
          message = 'A new attendance record student must belong to the session batch.';
      end if;
    end if;

  elsif tg_table_name = 'attendance_correction_requests' then
    select cs.batch_id
      into parent_batch_id
      from public.class_sessions cs
     where cs.id = new.session_id;

    if not found then
      raise exception using
        errcode = '23503',
        message = 'The correction request class session does not exist.';
    end if;

    if parent_batch_id is distinct from new.batch_id then
      raise exception using
        errcode = '23514',
        message = 'A correction request must use its class session batch.';
    end if;

    if tg_op = 'INSERT'
       or new.student_id is distinct from old.student_id
       or new.batch_id is distinct from old.batch_id then
      select p.batch_id
        into student_batch_id
        from public.profiles p
       where p.id = new.student_id;

      if not found or student_batch_id is distinct from new.batch_id then
        raise exception using
          errcode = '23514',
          message = 'The correction requester must belong to the request batch.';
      end if;
    end if;

    if new.record_id is not null then
      select ar.session_id, ar.student_id, ar.batch_id
        into record_session_id, record_student_id, record_batch_id
        from public.attendance_records ar
       where ar.id = new.record_id;

      if not found then
        raise exception using
          errcode = '23503',
          message = 'The correction request attendance record does not exist.';
      end if;

      if record_session_id is distinct from new.session_id
         or record_student_id is distinct from new.student_id
         or record_batch_id is distinct from new.batch_id then
        raise exception using
          errcode = '23514',
          message = 'A correction request must match its attendance record.';
      end if;
    end if;

  elsif tg_table_name = 'class_schedules' then
    if new.offering_id is not null then
      select co.batch_id
        into parent_batch_id
        from public.course_offerings co
       where co.id = new.offering_id;

      if not found then
        raise exception using
          errcode = '23503',
          message = 'The referenced course offering does not exist.';
      end if;

      if parent_batch_id is distinct from new.batch_id then
        raise exception using
          errcode = '23514',
          message = 'The referenced course offering must belong to the row batch.';
      end if;
    end if;

    if new.original_schedule_id is not null then
      select s.batch_id
        into parent_batch_id
        from public.class_schedules s
       where s.id = new.original_schedule_id;

      if not found or parent_batch_id is distinct from new.batch_id then
        raise exception using
          errcode = '23514',
          message = 'A rescheduled class must reference a schedule in the same batch.';
      end if;
    end if;

  elsif tg_table_name in ('exams', 'resources') then
    if new.offering_id is not null then
      select co.batch_id
        into parent_batch_id
        from public.course_offerings co
       where co.id = new.offering_id;

      if not found then
        raise exception using
          errcode = '23503',
          message = 'The referenced course offering does not exist.';
      end if;

      if parent_batch_id is distinct from new.batch_id then
        raise exception using
          errcode = '23514',
          message = 'The referenced course offering must belong to the row batch.';
      end if;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.validate_academic_relationships()
  from public, anon, authenticated;

drop trigger if exists trg_validate_offering_relationships
  on public.course_offerings;
create trigger trg_validate_offering_relationships
  before insert or update on public.course_offerings
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_session_relationships
  on public.class_sessions;
create trigger trg_validate_session_relationships
  before insert or update on public.class_sessions
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_attendance_relationships
  on public.attendance_records;
create trigger trg_validate_attendance_relationships
  before insert or update on public.attendance_records
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_correction_relationships
  on public.attendance_correction_requests;
create trigger trg_validate_correction_relationships
  before insert or update on public.attendance_correction_requests
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_schedule_relationships
  on public.class_schedules;
create trigger trg_validate_schedule_relationships
  before insert or update on public.class_schedules
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_exam_relationships on public.exams;
create trigger trg_validate_exam_relationships
  before insert or update on public.exams
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_resource_relationships on public.resources;
create trigger trg_validate_resource_relationships
  before insert or update on public.resources
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_course_department on public.courses;
create trigger trg_validate_course_department
  before update of department_id on public.courses
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_batch_program on public.batches;
create trigger trg_validate_batch_program
  before update of program_id on public.batches
  for each row execute function private.validate_academic_relationships();

drop trigger if exists trg_validate_program_department on public.programs;
create trigger trg_validate_program_department
  before update of department_id on public.programs
  for each row execute function private.validate_academic_relationships();

-- current_term and the graduated boundary have audited side effects and are
-- therefore RPC-owned. Other admin lifecycle states (delayed/suspended/etc.)
-- remain ordinary editable fields.
create or replace function public.advance_batch(target_batch uuid)
returns public.batches
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  batch_row public.batches;
  max_terms smallint;
  old_term smallint;
  old_status public.batch_status;
begin
  if not (
    private.is_cr_of_batch(target_batch)
    or private.is_super_admin()
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the batch CR or an active AAL2 super admin can advance the batch.';
  end if;

  select b.*
    into batch_row
    from public.batches b
   where b.id = target_batch
   for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Batch was not found.';
  end if;

  select p.total_terms
    into max_terms
    from public.programs p
   where p.id = batch_row.program_id;

  if batch_row.status = 'graduated'::public.batch_status then
    raise exception using
      errcode = '23514',
      message = 'The batch has already graduated.';
  end if;

  old_term := batch_row.current_term;
  old_status := batch_row.status;

  perform pg_catalog.set_config('app.advance_batch', 'on', true);

  if batch_row.current_term >= max_terms then
    update public.batches
       set status = 'graduated'::public.batch_status,
           updated_at = now()
     where id = target_batch
     returning * into batch_row;
  else
    update public.batches
       set current_term = current_term + 1,
           updated_at = now()
     where id = target_batch
     returning * into batch_row;
  end if;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data
  )
  values (
    actor_id,
    'batch.advanced',
    'batch',
    target_batch,
    jsonb_build_object(
      'current_term', old_term,
      'status', old_status::text
    ),
    jsonb_build_object(
      'current_term', batch_row.current_term,
      'status', batch_row.status::text
    )
  );

  return batch_row;
end;
$$;

revoke all on function public.advance_batch(uuid) from public, anon;
grant execute on function public.advance_batch(uuid) to authenticated;

create or replace function private.guard_batch_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  rpc_owner name;
  trusted_advance boolean := false;
  total_terms smallint;
  protected_change boolean;
begin
  if actor_id is null then
    return new;
  end if;

  select p.total_terms
    into total_terms
    from public.programs p
   where p.id = new.program_id;

  if not found then
    raise exception using
      errcode = '23503',
      message = 'The batch program does not exist.';
  end if;

  if new.current_term > total_terms then
    raise exception using
      errcode = '23514',
      message = 'A batch current term cannot exceed its program total terms.';
  end if;

  if tg_op = 'INSERT' then
    if new.status = 'graduated'::public.batch_status then
      raise exception using
        errcode = '23514',
        message = 'A new batch cannot start in the graduated state.';
    end if;
    return new;
  end if;

  protected_change :=
    new.current_term is distinct from old.current_term
    or (
      new.status is distinct from old.status
      and (
        new.status = 'graduated'::public.batch_status
        or old.status = 'graduated'::public.batch_status
      )
    );

  if not protected_change then
    return new;
  end if;

  select pg_catalog.pg_get_userbyid(p.proowner)
    into rpc_owner
    from pg_catalog.pg_proc p
   where p.oid = pg_catalog.to_regprocedure('public.advance_batch(uuid)');

  trusted_advance :=
    coalesce(current_user = rpc_owner, false)
    and coalesce(
      pg_catalog.current_setting('app.advance_batch', true),
      'off'
    ) = 'on';

  if not trusted_advance then
    raise exception using
      errcode = '42501',
      message = 'Advance current_term and graduation through advance_batch().';
  end if;

  return new;
end;
$$;

revoke all on function private.guard_batch_lifecycle()
  from public, anon, authenticated;

drop trigger if exists trg_batches_lifecycle_guard on public.batches;
create trigger trg_batches_lifecycle_guard
  before insert or update on public.batches
  for each row execute function private.guard_batch_lifecycle();

-- ---------------------------------------------------------------------------
-- Guarded request-review workflows
-- ---------------------------------------------------------------------------
-- Request identity and review fields are state-machine fields, not ordinary
-- editable columns. The RPCs below own transitions; a trigger still permits a
-- requester to perform the one direct transition exposed by existing RLS:
-- pending -> cancelled.

create or replace function public.review_batch_change_request(
  request_id uuid,
  approve boolean
)
returns public.batch_change_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  req public.batch_change_requests;
  student_profile public.profiles%rowtype;
begin
  if approve is null then
    raise exception using
      errcode = '22004',
      message = 'approve is required.';
  end if;

  select r.*
    into req
    from public.batch_change_requests r
   where r.id = request_id
   for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Batch change request was not found.';
  end if;

  if req.status <> 'pending'::public.request_status then
    raise exception using
      errcode = '23514',
      message = 'The batch change request has already been reviewed.';
  end if;

  if not (
    private.is_cr_of_batch(req.to_batch_id)
    or private.is_super_admin()
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the destination batch CR or an active AAL2 super admin can review this request.';
  end if;

  if approve then
    select p.*
      into student_profile
      from public.profiles p
     where p.id = req.student_id
     for update;

    if not found then
      raise exception using
        errcode = 'P0002',
        message = 'The request student profile was not found.';
    end if;

    if student_profile.batch_id is distinct from req.from_batch_id then
      raise exception using
        errcode = '23514',
        message = 'The student no longer belongs to the request source batch.';
    end if;

    if student_profile.role <> 'student'::public.user_role then
      raise exception using
        errcode = '23514',
        message = 'Only a student profile can be moved through a batch-change request.';
    end if;
  end if;

  perform pg_catalog.set_config(
    'app.review_batch_change_request',
    'on',
    true
  );

  update public.batch_change_requests
     set status = case
                    when approve then 'accepted'::public.request_status
                    else 'rejected'::public.request_status
                  end,
         reviewed_by = actor_id,
         reviewed_at = now(),
         updated_at = now()
   where id = request_id
   returning * into req;

  if approve then
    update public.profiles
       set batch_id = req.to_batch_id,
           updated_at = now()
     where id = req.student_id;
  end if;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data,
    metadata
  )
  values (
    actor_id,
    case when approve
      then 'batch_change.accepted'
      else 'batch_change.rejected'
    end,
    'batch_change_request',
    req.id,
    jsonb_build_object(
      'status', 'pending',
      'batch_id', req.from_batch_id
    ),
    jsonb_build_object(
      'status', req.status::text,
      'batch_id', case when approve then req.to_batch_id else req.from_batch_id end
    ),
    jsonb_build_object(
      'student_id', req.student_id,
      'from_batch_id', req.from_batch_id,
      'to_batch_id', req.to_batch_id,
      'source', 'protected_workflow'
    )
  );

  return req;
end;
$$;

revoke all on function public.review_batch_change_request(uuid, boolean)
  from public, anon;
grant execute on function public.review_batch_change_request(uuid, boolean)
  to authenticated;

comment on function public.review_batch_change_request(uuid, boolean) is
  'Atomically accepts/rejects a pending batch move, moves a non-CR profile only on acceptance, and audits the transition.';

create or replace function public.review_attendance_correction_request(
  request_id uuid,
  approve boolean
)
returns public.attendance_correction_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  req public.attendance_correction_requests;
  attendance_record public.attendance_records%rowtype;
  session_batch_id uuid;
  old_attendance_status public.attendance_status;
begin
  if approve is null then
    raise exception using
      errcode = '22004',
      message = 'approve is required.';
  end if;

  select r.*
    into req
    from public.attendance_correction_requests r
   where r.id = request_id
   for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Attendance correction request was not found.';
  end if;

  if req.status <> 'pending'::public.request_status then
    raise exception using
      errcode = '23514',
      message = 'The attendance correction request has already been reviewed.';
  end if;

  if not (
    private.is_cr_of_batch(req.batch_id)
    or private.is_super_admin()
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the batch CR or an active AAL2 super admin can review this request.';
  end if;

  if approve then
    -- Locking the parent session also serializes a concurrent first attendance
    -- insert, whose foreign-key check takes a conflicting key-share lock.
    select cs.batch_id
      into session_batch_id
      from public.class_sessions cs
     where cs.id = req.session_id
     for update;

    if not found then
      raise exception using
        errcode = 'P0002',
        message = 'The correction request class session was not found.';
    end if;

    if session_batch_id is distinct from req.batch_id then
      raise exception using
        errcode = '23514',
        message = 'The correction request session does not belong to its batch.';
    end if;

    if req.record_id is not null then
      select ar.*
        into attendance_record
        from public.attendance_records ar
       where ar.id = req.record_id
       for update;
    else
      select ar.*
        into attendance_record
        from public.attendance_records ar
       where ar.session_id = req.session_id
         and ar.student_id = req.student_id
       for update;
    end if;

    if found then
      if attendance_record.session_id is distinct from req.session_id
         or attendance_record.student_id is distinct from req.student_id
         or attendance_record.batch_id is distinct from req.batch_id then
        raise exception using
          errcode = '23514',
          message = 'The correction request does not match its attendance record.';
      end if;

      old_attendance_status := attendance_record.status;

      update public.attendance_records
         set status = req.requested_status,
             recorded_by = actor_id,
             updated_at = now()
       where id = attendance_record.id
       returning * into attendance_record;
    else
      if req.record_id is not null then
        raise exception using
          errcode = 'P0002',
          message = 'The correction request attendance record was not found.';
      end if;

      insert into public.attendance_records (
        session_id,
        student_id,
        batch_id,
        status,
        recorded_by
      )
      values (
        req.session_id,
        req.student_id,
        req.batch_id,
        req.requested_status,
        actor_id
      )
      returning * into attendance_record;
    end if;
  end if;

  perform pg_catalog.set_config(
    'app.review_attendance_correction_request',
    'on',
    true
  );

  update public.attendance_correction_requests
     set record_id = case
                       when approve then attendance_record.id
                       else req.record_id
                     end,
         status = case
                    when approve then 'accepted'::public.request_status
                    else 'rejected'::public.request_status
                  end,
         reviewed_by = actor_id,
         reviewed_at = now(),
         updated_at = now()
   where id = request_id
   returning * into req;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data,
    metadata
  )
  values (
    actor_id,
    case when approve
      then 'attendance_correction.accepted'
      else 'attendance_correction.rejected'
    end,
    'attendance_correction_request',
    req.id,
    jsonb_build_object(
      'status', 'pending',
      'record_id', req.record_id,
      'attendance_status', old_attendance_status
    ),
    jsonb_build_object(
      'status', req.status::text,
      'record_id', req.record_id,
      'attendance_status', case when approve then req.requested_status else old_attendance_status end
    ),
    jsonb_build_object(
      'student_id', req.student_id,
      'session_id', req.session_id,
      'batch_id', req.batch_id,
      'source', 'protected_workflow'
    )
  );

  return req;
end;
$$;

revoke all on function public.review_attendance_correction_request(uuid, boolean)
  from public, anon;
grant execute on function public.review_attendance_correction_request(uuid, boolean)
  to authenticated;

comment on function public.review_attendance_correction_request(uuid, boolean) is
  'Atomically accepts/rejects a pending attendance correction, applies or creates the matching attendance record only on acceptance, and audits the transition.';

create or replace function private.guard_request_workflow_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  rpc_owner name;
  trusted_review boolean := false;
  self_cancel boolean := false;
  protected_change boolean := false;
begin
  -- Preserve owner/service maintenance and seed operations. Browser JWT-backed
  -- mutations always have auth.uid() and must obey the state machine.
  if actor_id is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'pending'::public.request_status
       or new.reviewed_by is not null
       or new.reviewed_at is not null then
      raise exception using
        errcode = '23514',
        message = 'A new request must be pending and unreviewed.';
    end if;
    return new;
  end if;

  if tg_table_name = 'batch_change_requests' then
    select pg_catalog.pg_get_userbyid(p.proowner)
      into rpc_owner
      from pg_catalog.pg_proc p
     where p.oid = pg_catalog.to_regprocedure(
       'public.review_batch_change_request(uuid,boolean)'
     );

    trusted_review :=
      coalesce(current_user = rpc_owner, false)
      and coalesce(
        pg_catalog.current_setting(
          'app.review_batch_change_request',
          true
        ),
        'off'
      ) = 'on';

    protected_change :=
      new.student_id is distinct from old.student_id
      or new.from_batch_id is distinct from old.from_batch_id
      or new.to_batch_id is distinct from old.to_batch_id
      or new.status is distinct from old.status
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at;

    self_cancel :=
      old.student_id = actor_id
      and old.status = 'pending'::public.request_status
      and new.status = 'cancelled'::public.request_status
      and new.student_id is not distinct from old.student_id
      and new.from_batch_id is not distinct from old.from_batch_id
      and new.to_batch_id is not distinct from old.to_batch_id
      and new.reviewed_by is not distinct from old.reviewed_by
      and new.reviewed_at is not distinct from old.reviewed_at;
  else
    select pg_catalog.pg_get_userbyid(p.proowner)
      into rpc_owner
      from pg_catalog.pg_proc p
     where p.oid = pg_catalog.to_regprocedure(
       'public.review_attendance_correction_request(uuid,boolean)'
     );

    trusted_review :=
      coalesce(current_user = rpc_owner, false)
      and coalesce(
        pg_catalog.current_setting(
          'app.review_attendance_correction_request',
          true
        ),
        'off'
      ) = 'on';

    protected_change :=
      new.record_id is distinct from old.record_id
      or new.session_id is distinct from old.session_id
      or new.student_id is distinct from old.student_id
      or new.batch_id is distinct from old.batch_id
      or new.requested_status is distinct from old.requested_status
      or new.status is distinct from old.status
      or new.reviewed_by is distinct from old.reviewed_by
      or new.reviewed_at is distinct from old.reviewed_at;

    self_cancel :=
      old.student_id = actor_id
      and old.status = 'pending'::public.request_status
      and new.status = 'cancelled'::public.request_status
      and new.record_id is not distinct from old.record_id
      and new.session_id is not distinct from old.session_id
      and new.student_id is not distinct from old.student_id
      and new.batch_id is not distinct from old.batch_id
      and new.requested_status is not distinct from old.requested_status
      and new.reviewed_by is not distinct from old.reviewed_by
      and new.reviewed_at is not distinct from old.reviewed_at;
  end if;

  if protected_change and not trusted_review and not self_cancel then
    raise exception using
      errcode = '42501',
      message = 'Request identity and review fields must be changed through the protected review workflow.';
  end if;

  return new;
end;
$$;

revoke all on function private.guard_request_workflow_fields()
  from public, anon, authenticated;

drop trigger if exists trg_batch_change_workflow_guard
  on public.batch_change_requests;
create trigger trg_batch_change_workflow_guard
  before insert or update on public.batch_change_requests
  for each row execute function private.guard_request_workflow_fields();

drop trigger if exists trg_attendance_correction_workflow_guard
  on public.attendance_correction_requests;
create trigger trg_attendance_correction_workflow_guard
  before insert or update on public.attendance_correction_requests
  for each row execute function private.guard_request_workflow_fields();

-- ---------------------------------------------------------------------------
-- Allow-listed public-schema catalog for the generic database explorer
-- ---------------------------------------------------------------------------
-- No arbitrary identifiers or SQL are accepted. Only relation/column metadata
-- from pg_catalog for the public schema is returned. Foreign-key targets may
-- name another schema (for example profiles.id -> auth.users), but objects in
-- those schemas are not enumerated; function/view definitions and row values
-- are never exposed.

create or replace function public.admin_schema_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  catalog jsonb;
begin
  if not private.is_super_admin() then
    raise exception using
      errcode = '42501',
      message = 'Only an active super admin can inspect the database catalog.';
  end if;

  with relations as (
    select
      c.oid,
      n.nspname as schema_name,
      c.relname as relation_name,
      c.relkind,
      case c.relkind
        when 'r' then 'table'
        when 'p' then 'partitioned_table'
        when 'v' then 'view'
        when 'm' then 'materialized_view'
        when 'f' then 'foreign_table'
        else 'relation'
      end as relation_kind,
      case
        when c.relkind in ('r', 'p', 'm', 'f')
          then greatest(c.reltuples, 0)::bigint
        else 0::bigint
      end as estimated_rows,
      case
        when c.relkind in ('r', 'p', 'm')
          then pg_catalog.pg_total_relation_size(c.oid)
        else 0::bigint
      end as total_bytes
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p', 'v', 'm', 'f')
  )
  select jsonb_build_object(
    'schema', 'public',
    'generated_at', statement_timestamp(),
    'enums', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'schema', enum_ns.nspname,
            'name', enum_type.typname,
            'values', (
              select coalesce(
                jsonb_agg(enum_value.enumlabel order by enum_value.enumsortorder),
                '[]'::jsonb
              )
              from pg_catalog.pg_enum enum_value
              where enum_value.enumtypid = enum_type.oid
            )
          )
          order by enum_type.typname
        ),
        '[]'::jsonb
      )
      from pg_catalog.pg_type enum_type
      join pg_catalog.pg_namespace enum_ns on enum_ns.oid = enum_type.typnamespace
      where enum_ns.nspname = 'public'
        and enum_type.typtype = 'e'
    ),
    'relations', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'schema', r.schema_name,
          'name', r.relation_name,
          'kind', r.relation_kind,
          'comment', pg_catalog.obj_description(r.oid, 'pg_class'),
          'estimated_rows', r.estimated_rows,
          'total_bytes', r.total_bytes,
          'primary_key', (
            select coalesce(
              jsonb_agg(pk_attribute.attname order by pk_key.ordinality),
              '[]'::jsonb
            )
            from pg_catalog.pg_constraint pk
            cross join lateral unnest(pk.conkey)
              with ordinality as pk_key(attnum, ordinality)
            join pg_catalog.pg_attribute pk_attribute
              on pk_attribute.attrelid = pk.conrelid
             and pk_attribute.attnum = pk_key.attnum
            where pk.conrelid = r.oid
              and pk.contype = 'p'
          ),
          'foreign_keys', (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'name', fk.conname,
                  'columns', (
                    select jsonb_agg(source_attribute.attname order by source_key.ordinality)
                    from unnest(fk.conkey)
                      with ordinality as source_key(attnum, ordinality)
                    join pg_catalog.pg_attribute source_attribute
                      on source_attribute.attrelid = fk.conrelid
                     and source_attribute.attnum = source_key.attnum
                  ),
                  'referenced_schema', referenced_ns.nspname,
                  'referenced_table', referenced_relation.relname,
                  'referenced_columns', (
                    select jsonb_agg(referenced_attribute.attname order by referenced_key.ordinality)
                    from unnest(fk.confkey)
                      with ordinality as referenced_key(attnum, ordinality)
                    join pg_catalog.pg_attribute referenced_attribute
                      on referenced_attribute.attrelid = fk.confrelid
                     and referenced_attribute.attnum = referenced_key.attnum
                  ),
                  'on_update', case fk.confupdtype
                    when 'a' then 'no_action'
                    when 'r' then 'restrict'
                    when 'c' then 'cascade'
                    when 'n' then 'set_null'
                    when 'd' then 'set_default'
                  end,
                  'on_delete', case fk.confdeltype
                    when 'a' then 'no_action'
                    when 'r' then 'restrict'
                    when 'c' then 'cascade'
                    when 'n' then 'set_null'
                    when 'd' then 'set_default'
                  end,
                  'deferrable', fk.condeferrable,
                  'initially_deferred', fk.condeferred
                )
                order by fk.conname
              ),
              '[]'::jsonb
            )
            from pg_catalog.pg_constraint fk
            join pg_catalog.pg_class referenced_relation
              on referenced_relation.oid = fk.confrelid
            join pg_catalog.pg_namespace referenced_ns
              on referenced_ns.oid = referenced_relation.relnamespace
            where fk.conrelid = r.oid
              and fk.contype = 'f'
          ),
          'columns', (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'ordinal_position', attribute.attnum,
                  'name', attribute.attname,
                  -- `data_type`/`base_type` are the stable form-builder keys;
                  -- the schema/type fields preserve the richer catalog detail.
                  'data_type', pg_catalog.format_type(attribute.atttypid, attribute.atttypmod),
                  'base_type', attribute_type.typname,
                  'type', pg_catalog.format_type(attribute.atttypid, attribute.atttypmod),
                  'type_schema', type_ns.nspname,
                  'type_name', attribute_type.typname,
                  'nullable', not attribute.attnotnull,
                  'default', pg_catalog.pg_get_expr(
                    attribute_default.adbin,
                    attribute_default.adrelid,
                    true
                  ),
                  'primary_key', exists (
                    select 1
                    from pg_catalog.pg_constraint column_pk
                    where column_pk.conrelid = r.oid
                      and column_pk.contype = 'p'
                      and attribute.attnum = any(column_pk.conkey)
                  ),
                  'identity', attribute.attidentity <> '',
                  'identity_generation', case attribute.attidentity
                    when 'a' then 'always'
                    when 'd' then 'by_default'
                    else null
                  end,
                  'generated', attribute.attgenerated <> '',
                  'generation_kind', nullif(attribute.attgenerated, ''),
                  'enum_values', case
                    when attribute_type.typtype = 'e' then (
                      select coalesce(
                        jsonb_agg(enum_value.enumlabel order by enum_value.enumsortorder),
                        '[]'::jsonb
                      )
                      from pg_catalog.pg_enum enum_value
                      where enum_value.enumtypid = attribute_type.oid
                    )
                    else null
                  end,
                  'foreign_key', (
                    select jsonb_build_object(
                      'schema', column_fk_ns.nspname,
                      'table', column_fk_relation.relname,
                      'column', column_fk_attribute.attname
                    )
                    from pg_catalog.pg_constraint column_fk
                    join pg_catalog.pg_class column_fk_relation
                      on column_fk_relation.oid = column_fk.confrelid
                    join pg_catalog.pg_namespace column_fk_ns
                      on column_fk_ns.oid = column_fk_relation.relnamespace
                    cross join lateral generate_subscripts(column_fk.conkey, 1)
                      as column_fk_position(position)
                    join pg_catalog.pg_attribute column_fk_attribute
                      on column_fk_attribute.attrelid = column_fk.confrelid
                     and column_fk_attribute.attnum =
                       column_fk.confkey[column_fk_position.position]
                    where column_fk.conrelid = r.oid
                      and column_fk.contype = 'f'
                      and column_fk.conkey[column_fk_position.position] = attribute.attnum
                    order by column_fk.conname
                    limit 1
                  ),
                  'comment', pg_catalog.col_description(r.oid, attribute.attnum)
                )
                order by attribute.attnum
              ),
              '[]'::jsonb
            )
            from pg_catalog.pg_attribute attribute
            join pg_catalog.pg_type attribute_type
              on attribute_type.oid = attribute.atttypid
            join pg_catalog.pg_namespace type_ns
              on type_ns.oid = attribute_type.typnamespace
            left join pg_catalog.pg_attrdef attribute_default
              on attribute_default.adrelid = attribute.attrelid
             and attribute_default.adnum = attribute.attnum
            where attribute.attrelid = r.oid
              and attribute.attnum > 0
              and not attribute.attisdropped
          )
        )
        order by r.relation_kind, r.relation_name
      ),
      '[]'::jsonb
    )
  )
  into catalog
  from relations r;

  return catalog;
end;
$$;

revoke all on function public.admin_schema_catalog() from public;
revoke all on function public.admin_schema_catalog() from anon;
grant execute on function public.admin_schema_catalog() to authenticated;

comment on function public.admin_schema_catalog() is
  'Returns allow-listed structural metadata for every public table/view to active super admins; never returns row data or non-public schema metadata.';

-- ---------------------------------------------------------------------------
-- Missing super-admin operational policies
-- ---------------------------------------------------------------------------
-- Existing self/owner policies remain intact. These explicitly named policies
-- add only the super-admin branch needed by the admin panel. No write policy is
-- added to audit_logs or attendance_history, and views remain read-only.

-- Assignment mutations must go through admin_set_cr so role and assignment
-- rows cannot drift. The existing cr_assignments_read policy still lets the
-- super admin and relevant users inspect assignments.
drop policy if exists cr_assignments_admin on public.cr_assignments;

drop policy if exists notifications_super_admin_all on public.notifications;
create policy notifications_super_admin_all on public.notifications
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists bus_favorites_super_admin_all on public.bus_route_favorites;
create policy bus_favorites_super_admin_all on public.bus_route_favorites
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists notice_reads_super_admin_all on public.notice_reads;
create policy notice_reads_super_admin_all on public.notice_reads
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists attendance_corrections_super_admin_all
  on public.attendance_correction_requests;
create policy attendance_corrections_super_admin_all
  on public.attendance_correction_requests
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists batch_change_requests_super_admin_all
  on public.batch_change_requests;
create policy batch_change_requests_super_admin_all
  on public.batch_change_requests
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists blood_responses_super_admin_all
  on public.blood_request_responses;
create policy blood_responses_super_admin_all
  on public.blood_request_responses
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists lost_found_responses_super_admin_all
  on public.lost_found_responses;
create policy lost_found_responses_super_admin_all
  on public.lost_found_responses
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

-- Requests/items are author-created in the student app. Their existing read,
-- update, and delete policies already contain a super-admin branch; only the
-- ability to create a row on another user's behalf was missing.
drop policy if exists blood_requests_super_admin_insert on public.blood_requests;
create policy blood_requests_super_admin_insert on public.blood_requests
  for insert to authenticated
  with check ((select private.is_super_admin()));

drop policy if exists lost_found_items_super_admin_insert on public.lost_found_items;
create policy lost_found_items_super_admin_insert on public.lost_found_items
  for insert to authenticated
  with check ((select private.is_super_admin()));
