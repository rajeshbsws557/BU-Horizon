-- BU Horizon — 12. RLS: batch-scoped academic content
-- Pattern for every batch-owned table:
--   SELECT  → own batch members + that batch's CR + super admin
--   WRITE   → that batch's CR (full CRUD, but soft-delete via deleted_at) + super admin
-- "own batch" = private.current_batch(); "batch CR" = private.is_cr_of_batch().
-- Cross-batch and cross-department reads are blocked (poll Q28, Q29).

-- Helper predicate expressed inline per table (Postgres has no macro):
--   read:  batch_id = private.current_batch() OR private.is_cr_of_batch(batch_id) OR private.is_super_admin()
--   write: private.is_cr_of_batch(batch_id) OR private.is_super_admin()

-- ===========================================================================
-- Course offerings
-- ===========================================================================
create policy offerings_read on public.course_offerings
  for select to authenticated using (
    batch_id = private.current_batch()
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy offerings_write on public.course_offerings
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- ===========================================================================
-- Class sessions
-- ===========================================================================
create policy class_sessions_read on public.class_sessions
  for select to authenticated using (
    batch_id = private.current_batch()
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy class_sessions_write on public.class_sessions
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- ===========================================================================
-- Attendance records — students read their own batch's; CR records/edits.
-- ===========================================================================
create policy attendance_read on public.attendance_records
  for select to authenticated using (
    student_id = (select auth.uid())
    or batch_id = private.current_batch()
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy attendance_write on public.attendance_records
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- Attendance history — read-only for batch/CR/self; inserts happen via trigger
-- (SECURITY DEFINER), so no INSERT policy is granted to clients.
create policy attendance_history_read on public.attendance_history
  for select to authenticated using (
    exists (
      select 1 from public.attendance_records ar
      where ar.id = attendance_history.record_id
        and (
          ar.student_id = (select auth.uid())
          or ar.batch_id = private.current_batch()
          or private.is_cr_of_batch(ar.batch_id)
          or private.is_super_admin()
        )
    )
  );

-- ===========================================================================
-- Attendance correction requests — student creates own; CR reviews (poll Q42).
-- ===========================================================================
create policy attendance_corr_read on public.attendance_correction_requests
  for select to authenticated using (
    student_id = (select auth.uid())
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy attendance_corr_insert on public.attendance_correction_requests
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and batch_id = private.current_batch()
  );
-- Student may cancel own pending request; CR/admin may review (update status).
create policy attendance_corr_student_update on public.attendance_correction_requests
  for update to authenticated
  using (student_id = (select auth.uid()) and status = 'pending')
  with check (student_id = (select auth.uid()));
create policy attendance_corr_cr_update on public.attendance_correction_requests
  for update to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- ===========================================================================
-- Class schedules
-- ===========================================================================
create policy schedules_read on public.class_schedules
  for select to authenticated using (
    batch_id = private.current_batch()
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy schedules_write on public.class_schedules
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- ===========================================================================
-- Exams
-- ===========================================================================
create policy exams_read on public.exams
  for select to authenticated using (
    batch_id = private.current_batch()
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy exams_write on public.exams
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- ===========================================================================
-- Resources
-- ===========================================================================
create policy resources_read on public.resources
  for select to authenticated using (
    batch_id = private.current_batch()
    or private.is_cr_of_batch(batch_id)
    or private.is_super_admin()
  );
create policy resources_write on public.resources
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or private.is_super_admin())
  with check (private.is_cr_of_batch(batch_id) or private.is_super_admin());

-- ===========================================================================
-- Batch-change requests (poll Q7)
-- Student creates a request FROM their current batch. Reads: the requester, the
-- destination-batch CR (who accepts), and super admin. Status changes go
-- through review_batch_change_request() so no client UPDATE policy is granted.
-- ===========================================================================
create policy batch_change_read on public.batch_change_requests
  for select to authenticated using (
    student_id = (select auth.uid())
    or private.is_cr_of_batch(to_batch_id)
    or private.is_cr_of_batch(from_batch_id)
    or private.is_super_admin()
  );
create policy batch_change_insert on public.batch_change_requests
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and from_batch_id = private.current_batch()
  );
-- Student may cancel their own pending request.
create policy batch_change_cancel on public.batch_change_requests
  for update to authenticated
  using (student_id = (select auth.uid()) and status = 'pending')
  with check (student_id = (select auth.uid()) and status = 'cancelled');
