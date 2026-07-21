-- Guest access, attendance privacy, CR course management, in-app responses.
--
-- Product-owner decisions (2026-07-21):
--   1. The app opens without login. Guests may read the bus schedule, and the
--      registration form needs the academic reference tables before the user
--      is authenticated. Everything else stays login-only.
--   2. Attendance is private: a student sees only their OWN records; the
--      batch CR and the super admin see the whole batch.
--   3. CRs manage the course catalogue of their own department (soft-delete
--      only, like all CR-owned content).
--   4. Responses to blood requests and lost & found items are recorded
--      in-app, visible to the responder and the request/item owner.

-- 1 ▸ Anonymous read access ---------------------------------------------------
-- Table-level SELECT grants for anon already exist (Supabase defaults); these
-- policies are what actually open the gate. Reference tables are needed by the
-- pre-auth registration form (faculty/department dropdowns + batch resolution).

create policy bus_routes_public_read on public.bus_routes
  for select to anon using (true);

create policy bus_trips_public_read on public.bus_trips
  for select to anon using (true);

create policy faculties_public_read on public.faculties
  for select to anon using (true);

create policy departments_public_read on public.departments
  for select to anon using (true);

create policy programs_public_read on public.programs
  for select to anon using (true);

create policy batches_public_read on public.batches
  for select to anon using (true);

-- 2 ▸ Attendance privacy ------------------------------------------------------
-- Was: any member of the batch could read the whole batch's records.

drop policy attendance_read on public.attendance_records;
create policy attendance_read on public.attendance_records
  for select to authenticated
  using (
    student_id = (select auth.uid())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

drop policy attendance_history_read on public.attendance_history;
create policy attendance_history_read on public.attendance_history
  for select to authenticated
  using (
    exists (
      select 1
      from public.attendance_records ar
      where ar.id = record_id
        and (
          ar.student_id = (select auth.uid())
          or private.is_cr_of_batch(ar.batch_id)
          or (select private.is_super_admin())
        )
    )
  );

-- 3 ▸ CR course management ----------------------------------------------------
-- Courses hang off departments, so CR rights are resolved through the CR's
-- batch → program → department.

create function private.is_cr_of_department(target_department uuid)
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
      and pr.role = 'cr'
      and p.department_id = target_department
  );
$$;

revoke execute on function private.is_cr_of_department(uuid) from anon;
grant execute on function private.is_cr_of_department(uuid) to authenticated;

-- CRs may see their department's soft-deleted courses (restoration).
drop policy courses_read on public.courses;
create policy courses_read on public.courses
  for select to authenticated
  using (
    deleted_at is null
    or private.is_cr_of_department(department_id)
    or (select private.is_super_admin())
  );

create policy courses_cr_insert on public.courses
  for insert to authenticated
  with check (private.is_cr_of_department(department_id));

-- Update covers edits AND soft delete/restore (deleted_at). No DELETE policy
-- for CRs: hard delete stays super-admin-only, per the soft-delete house rule.
create policy courses_cr_update on public.courses
  for update to authenticated
  using (private.is_cr_of_department(department_id))
  with check (private.is_cr_of_department(department_id));

-- 4 ▸ In-app responses --------------------------------------------------------

create table public.blood_request_responses (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.blood_requests (id) on delete cascade,
  responder_id uuid not null references public.profiles (id) on delete cascade,
  message text,
  contact text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (request_id, responder_id)
);

create table public.lost_found_responses (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.lost_found_items (id) on delete cascade,
  responder_id uuid not null references public.profiles (id) on delete cascade,
  message text,
  contact text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, responder_id)
);

create index idx_blood_responses_request on public.blood_request_responses (request_id);
create index idx_blood_responses_responder on public.blood_request_responses (responder_id);
create index idx_lost_found_responses_item on public.lost_found_responses (item_id);
create index idx_lost_found_responses_responder on public.lost_found_responses (responder_id);

create trigger set_updated_at
  before update on public.blood_request_responses
  for each row execute function private.set_updated_at();

create trigger set_updated_at
  before update on public.lost_found_responses
  for each row execute function private.set_updated_at();

alter table public.blood_request_responses enable row level security;
alter table public.lost_found_responses enable row level security;

create policy blood_responses_insert on public.blood_request_responses
  for insert to authenticated
  with check (responder_id = (select auth.uid()));

-- Contact details stay between the responder and the requester.
create policy blood_responses_read on public.blood_request_responses
  for select to authenticated
  using (
    responder_id = (select auth.uid())
    or exists (
      select 1 from public.blood_requests r
      where r.id = request_id and r.requester_id = (select auth.uid())
    )
    or (select private.is_super_admin())
  );

create policy blood_responses_update on public.blood_request_responses
  for update to authenticated
  using (responder_id = (select auth.uid()))
  with check (responder_id = (select auth.uid()));

create policy blood_responses_delete on public.blood_request_responses
  for delete to authenticated
  using (
    responder_id = (select auth.uid())
    or (select private.is_super_admin())
  );

create policy lost_found_responses_insert on public.lost_found_responses
  for insert to authenticated
  with check (responder_id = (select auth.uid()));

create policy lost_found_responses_read on public.lost_found_responses
  for select to authenticated
  using (
    responder_id = (select auth.uid())
    or exists (
      select 1 from public.lost_found_items i
      where i.id = item_id and i.reporter_id = (select auth.uid())
    )
    or (select private.is_super_admin())
  );

create policy lost_found_responses_update on public.lost_found_responses
  for update to authenticated
  using (responder_id = (select auth.uid()))
  with check (responder_id = (select auth.uid()));

create policy lost_found_responses_delete on public.lost_found_responses
  for delete to authenticated
  using (
    responder_id = (select auth.uid())
    or (select private.is_super_admin())
  );
