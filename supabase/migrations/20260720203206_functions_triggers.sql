-- BU Horizon — 09. Functions and triggers
-- Helper functions live in the unexposed `private` schema so they are never
-- callable via the Data API. RLS-support helpers are SECURITY DEFINER to read
-- profiles without triggering recursive RLS; each is scoped to the current user
-- (auth.uid()) and does not accept arbitrary ids, so it cannot leak data.

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function private.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS helpers — read the caller's own role/department/batch without recursion.
-- SECURITY DEFINER + fixed search_path; they only ever read auth.uid()'s row.
-- ---------------------------------------------------------------------------
create or replace function private.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

create or replace function private.current_department()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select department_id from public.profiles where id = (select auth.uid());
$$;

create or replace function private.current_batch()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select batch_id from public.profiles where id = (select auth.uid());
$$;

create or replace function private.current_status()
returns public.profile_status
language sql
stable
security definer
set search_path = ''
as $$
  select status from public.profiles where id = (select auth.uid());
$$;

create or replace function private.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'super_admin' from public.profiles where id = (select auth.uid())),
    false
  );
$$;

-- True when the caller is an active CR of the given batch (poll Q34).
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
      and p.role = 'cr'
  );
$$;

-- ---------------------------------------------------------------------------
-- Mirror profile role into auth JWT app_metadata.
-- app_metadata is NOT user-editable, so it is safe for authorization. Kept in
-- sync so clients/edge functions can read role from the JWT if needed. RLS in
-- this project reads role via private.current_role() (DB source of truth).
-- ---------------------------------------------------------------------------
create or replace function private.sync_role_to_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
     set raw_app_meta_data =
       coalesce(raw_app_meta_data, '{}'::jsonb)
       || jsonb_build_object('app_role', new.role, 'batch_id', new.batch_id, 'department_id', new.department_id)
   where id = new.id;
  return new;
end;
$$;

create trigger trg_profiles_sync_role
  after insert or update of role, batch_id, department_id on public.profiles
  for each row execute function private.sync_role_to_auth();

-- ---------------------------------------------------------------------------
-- Auto-create a profile when a user signs up (self-registration, poll Q18/Q19).
-- Auto-approved: profile is created active immediately. Identity fields are
-- pulled from the sign-up metadata the client passes.
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, roll, student_id, phone, faculty_id, department_id, batch_id)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.raw_user_meta_data->>'roll',
    new.raw_user_meta_data->>'student_id',
    new.raw_user_meta_data->>'phone',
    nullif(new.raw_user_meta_data->>'faculty_id','')::uuid,
    nullif(new.raw_user_meta_data->>'department_id','')::uuid,
    nullif(new.raw_user_meta_data->>'batch_id','')::uuid
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Program academic system is immutable (poll Q3).
-- ---------------------------------------------------------------------------
create or replace function private.lock_academic_system()
returns trigger
language plpgsql
as $$
begin
  if new.academic_system <> old.academic_system then
    raise exception 'A program cannot switch between semester and yearly systems (poll Q3).';
  end if;
  return new;
end;
$$;

create trigger trg_programs_lock_system
  before update on public.programs
  for each row execute function private.lock_academic_system();

-- ---------------------------------------------------------------------------
-- CR cap: a batch may have at most two CRs (poll Q31).
-- ---------------------------------------------------------------------------
create or replace function private.enforce_cr_cap()
returns trigger
language plpgsql
as $$
declare
  cnt int;
begin
  select count(*) into cnt from public.cr_assignments where batch_id = new.batch_id;
  if cnt >= 2 then
    raise exception 'A batch can have at most two class representatives (poll Q31).';
  end if;
  return new;
end;
$$;

create trigger trg_cr_cap
  before insert on public.cr_assignments
  for each row execute function private.enforce_cr_cap();

-- ---------------------------------------------------------------------------
-- Attendance edit history (poll Q41).
-- ---------------------------------------------------------------------------
create or replace function private.log_attendance_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    insert into public.attendance_history (record_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, (select auth.uid()));
  elsif tg_op = 'INSERT' then
    insert into public.attendance_history (record_id, old_status, new_status, changed_by)
    values (new.id, null, new.status, (select auth.uid()));
  end if;
  return new;
end;
$$;

create trigger trg_attendance_history
  after insert or update on public.attendance_records
  for each row execute function private.log_attendance_change();

-- ---------------------------------------------------------------------------
-- Audit log is append-only (poll Q58): block UPDATE/DELETE at table level.
-- ---------------------------------------------------------------------------
create or replace function private.block_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'audit_logs is immutable and append-only (poll Q58).';
end;
$$;

create trigger trg_audit_immutable
  before update or delete on public.audit_logs
  for each row execute function private.block_mutation();

-- ---------------------------------------------------------------------------
-- Batch-change acceptance RPC (poll Q7).
-- Only the DESTINATION batch's CR may accept. On acceptance the student's
-- batch_id is updated and the action is audited. Runs SECURITY DEFINER because
-- it writes another user's profile row, but it authorizes the caller first.
-- ---------------------------------------------------------------------------
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
  req public.batch_change_requests;
begin
  select * into req from public.batch_change_requests where id = request_id for update;
  if not found then
    raise exception 'Request not found.';
  end if;
  if req.status <> 'pending' then
    raise exception 'Request has already been reviewed.';
  end if;

  -- Authorization: caller must be an active CR of the destination batch, or a
  -- super admin. This is the CR "accepting only" privilege (poll Q34).
  if not (private.is_cr_of_batch(req.to_batch_id) or private.is_super_admin()) then
    raise exception 'Only the destination batch CR can review this request (poll Q7).';
  end if;

  update public.batch_change_requests
     set status = case when approve then 'accepted'::public.request_status
                       else 'rejected'::public.request_status end,
         reviewed_by = (select auth.uid()),
         reviewed_at = now(),
         updated_at = now()
   where id = request_id
   returning * into req;

  if approve then
    update public.profiles
       set batch_id = req.to_batch_id, updated_at = now()
     where id = req.student_id;

    insert into public.audit_logs (actor_id, action, entity_type, entity_id, old_data, new_data)
    values (
      (select auth.uid()), 'batch_change.accepted', 'profile', req.student_id,
      jsonb_build_object('batch_id', req.from_batch_id),
      jsonb_build_object('batch_id', req.to_batch_id)
    );
  end if;

  return req;
end;
$$;

revoke all on function public.review_batch_change_request(uuid, boolean) from public;
grant execute on function public.review_batch_change_request(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Advance a batch to its next term, or graduate it on the final term (poll Q40).
-- Only an active CR of the batch (or super admin) may call it.
-- ---------------------------------------------------------------------------
create or replace function public.advance_batch(target_batch uuid)
returns public.batches
language plpgsql
security definer
set search_path = ''
as $$
declare
  b public.batches;
  max_terms smallint;
begin
  if not (private.is_cr_of_batch(target_batch) or private.is_super_admin()) then
    raise exception 'Only the batch CR can advance the batch (poll Q40).';
  end if;

  select p.total_terms into max_terms
  from public.batches bb join public.programs p on p.id = bb.program_id
  where bb.id = target_batch;

  select * into b from public.batches where id = target_batch for update;

  if b.current_term >= max_terms then
    update public.batches set status = 'graduated', updated_at = now()
     where id = target_batch returning * into b;
  else
    update public.batches set current_term = current_term + 1, updated_at = now()
     where id = target_batch returning * into b;
  end if;

  insert into public.audit_logs (actor_id, action, entity_type, entity_id, new_data)
  values ((select auth.uid()), 'batch.advanced', 'batch', target_batch,
          jsonb_build_object('current_term', b.current_term, 'status', b.status));

  return b;
end;
$$;

revoke all on function public.advance_batch(uuid) from public;
grant execute on function public.advance_batch(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Attach updated_at triggers to every table that has the column.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'faculties','departments','programs','batches','profiles','courses',
    'course_offerings','class_sessions','attendance_records',
    'attendance_correction_requests','class_schedules','exams','notices',
    'resources','batch_change_requests','bus_routes','blood_requests',
    'blood_donors','lost_found_items'
  ]
  loop
    execute format(
      'create trigger trg_%1$s_updated_at before update on public.%1$s
         for each row execute function private.set_updated_at();', t);
  end loop;
end;
$$;
