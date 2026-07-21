-- BU Horizon — 11. RLS: enable everywhere + reference/academic-tree policies
-- Isolation model (poll Q28, Q29):
--   * Academic content is visible only within the user's own batch.
--   * Reference structure (faculties/departments/programs/batches, courses, bus
--     routes) is readable university-wide so registration and directories work.
--   * University-scoped public notices are readable by everyone.
--   * Super admin can do everything.
-- Writes to academic content are limited to the batch's CR (poll Q34) with
-- soft-delete only (poll Q35, Q59); super admin manages structure and CRs.

-- Enable RLS on every table in the public schema.
do $$
declare t text;
begin
  foreach t in array array[
    'faculties','departments','programs','batches','profiles','cr_assignments',
    'courses','course_offerings','class_sessions','attendance_records',
    'attendance_history','attendance_correction_requests','class_schedules',
    'exams','notices','notice_attachments','notice_reads','resources',
    'batch_change_requests','notifications','audit_logs',
    'bus_routes','bus_trips','bus_route_favorites','blood_requests',
    'blood_donors','lost_found_items','alerts'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
  end loop;
end;
$$;

-- ===========================================================================
-- Reference / academic tree — readable university-wide, writable by super admin
-- ===========================================================================

-- Faculties
create policy faculties_read on public.faculties
  for select to authenticated using (true);
create policy faculties_admin on public.faculties
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- Departments
create policy departments_read on public.departments
  for select to authenticated using (true);
create policy departments_admin on public.departments
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- Programs
create policy programs_read on public.programs
  for select to authenticated using (true);
create policy programs_admin on public.programs
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- Batches: everyone reads (needed for registration and batch-change targets);
-- super admin manages. CR term advance goes through advance_batch() RPC.
create policy batches_read on public.batches
  for select to authenticated using (true);
create policy batches_admin on public.batches
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- Courses: readable university-wide; super admin manages (one dept each, poll Q12).
create policy courses_read on public.courses
  for select to authenticated using (deleted_at is null or private.is_super_admin());
create policy courses_admin on public.courses
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- ===========================================================================
-- Profiles
-- ===========================================================================
-- A user always sees their own profile. Beyond that, the people directory view
-- (name/department/email only) is the sanctioned cross-department lookup, so the
-- base table stays tight: own row + super admin. CRs read their batch members
-- through batch-scoped policies on academic tables, and batch member listing is
-- granted below for CRs to manage requests (poll Q34).
create policy profiles_self_read on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_cr_read_batch on public.profiles
  for select to authenticated
  using (batch_id is not null and private.is_cr_of_batch(batch_id));

create policy profiles_admin_read on public.profiles
  for select to authenticated
  using (private.is_super_admin());

-- Users may edit their own mutable fields; role/status/batch changes are guarded
-- by the WITH CHECK below (a self-update cannot elevate role or move batch).
-- Uses SECURITY DEFINER helpers (private.current_*) rather than subqueries on
-- public.profiles, which would recurse through this very policy.
create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role = private.current_role()
    and status = private.current_status()
    and batch_id is not distinct from private.current_batch()
  );

create policy profiles_admin_all on public.profiles
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- ===========================================================================
-- CR assignments — super admin manages (poll Q32); users can see their batch CR.
-- ===========================================================================
create policy cr_assignments_read on public.cr_assignments
  for select to authenticated
  using (
    batch_id = private.current_batch()
    or profile_id = (select auth.uid())
    or private.is_super_admin()
  );
create policy cr_assignments_admin on public.cr_assignments
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());
