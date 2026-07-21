-- BU Horizon — 15. Security & performance hardening (post-deploy advisors)
-- Driven by `get_advisors` findings on the live project:
--   * anon could EXECUTE the authenticated-only SECURITY DEFINER RPCs — hosted
--     Supabase grants EXECUTE to anon/authenticated via ALTER DEFAULT PRIVILEGES,
--     and `revoke ... from public` does not remove those explicit grants.
--   * Four trigger functions had a role-mutable search_path.
--   * 19 foreign keys had no covering index.
--   * Zero-argument RLS helper calls are re-evaluated per row unless wrapped in
--     a scalar subquery; `(select fn())` turns them into a cached InitPlan.
--     Row-dependent calls (is_cr_of_batch(batch_id)) cannot be cached and stay.

-- ---------------------------------------------------------------------------
-- 1. Authenticated-only RPCs: remove the default anon grant.
--    resolve_login_email deliberately stays anon-callable (login screen).
-- ---------------------------------------------------------------------------
revoke execute on function public.advance_batch(uuid) from anon;
revoke execute on function public.review_batch_change_request(uuid, boolean) from anon;
revoke execute on function public.get_schedule_conflicts(uuid) from anon;

-- ---------------------------------------------------------------------------
-- 2. Pin search_path on trigger functions (bodies only touch NEW/OLD or fully
--    qualified tables, so '' is safe).
-- ---------------------------------------------------------------------------
alter function private.set_updated_at() set search_path = '';
alter function private.lock_academic_system() set search_path = '';
alter function private.enforce_cr_cap() set search_path = '';
alter function private.block_mutation() set search_path = '';

-- ---------------------------------------------------------------------------
-- 3. Covering indexes for foreign keys flagged by the performance advisor.
-- ---------------------------------------------------------------------------
create index idx_alerts_created_by on public.alerts (created_by);
create index idx_attendance_corrections_record on public.attendance_correction_requests (record_id);
create index idx_attendance_corrections_reviewed_by on public.attendance_correction_requests (reviewed_by);
create index idx_attendance_corrections_session on public.attendance_correction_requests (session_id);
create index idx_attendance_history_changed_by on public.attendance_history (changed_by);
create index idx_attendance_recorded_by on public.attendance_records (recorded_by);
create index idx_batch_change_from_batch on public.batch_change_requests (from_batch_id);
create index idx_batch_change_reviewed_by on public.batch_change_requests (reviewed_by);
create index idx_blood_requests_requester on public.blood_requests (requester_id);
create index idx_bus_route_favorites_route on public.bus_route_favorites (route_id);
create index idx_schedules_created_by on public.class_schedules (created_by);
create index idx_schedules_original on public.class_schedules (original_schedule_id);
create index idx_class_sessions_created_by on public.class_sessions (created_by);
create index idx_cr_assignments_assigned_by on public.cr_assignments (assigned_by);
create index idx_exams_created_by on public.exams (created_by);
create index idx_lost_found_reporter on public.lost_found_items (reporter_id);
create index idx_notices_created_by on public.notices (created_by);
create index idx_profiles_faculty on public.profiles (faculty_id);
create index idx_resources_created_by on public.resources (created_by);

-- ---------------------------------------------------------------------------
-- 4. Recreate policies with zero-arg helper calls wrapped in (select ...).
--    Semantics are unchanged; only evaluation strategy improves.
-- ---------------------------------------------------------------------------

-- Reference / academic tree ------------------------------------------------
drop policy faculties_admin on public.faculties;
create policy faculties_admin on public.faculties
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

drop policy departments_admin on public.departments;
create policy departments_admin on public.departments
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

drop policy programs_admin on public.programs;
create policy programs_admin on public.programs
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

drop policy batches_admin on public.batches;
create policy batches_admin on public.batches
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

drop policy courses_read on public.courses;
create policy courses_read on public.courses
  for select to authenticated
  using (deleted_at is null or (select private.is_super_admin()));
drop policy courses_admin on public.courses;
create policy courses_admin on public.courses
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

-- Profiles -------------------------------------------------------------------
drop policy profiles_admin_read on public.profiles;
create policy profiles_admin_read on public.profiles
  for select to authenticated
  using ((select private.is_super_admin()));

drop policy profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (
    id = (select auth.uid())
    and role = (select private.current_role())
    and status = (select private.current_status())
    and batch_id is not distinct from (select private.current_batch())
  );

drop policy profiles_admin_all on public.profiles;
create policy profiles_admin_all on public.profiles
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

-- CR assignments --------------------------------------------------------------
drop policy cr_assignments_read on public.cr_assignments;
create policy cr_assignments_read on public.cr_assignments
  for select to authenticated
  using (
    batch_id = (select private.current_batch())
    or profile_id = (select auth.uid())
    or (select private.is_super_admin())
  );
drop policy cr_assignments_admin on public.cr_assignments;
create policy cr_assignments_admin on public.cr_assignments
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

-- Batch-scoped academic content ------------------------------------------------
drop policy offerings_read on public.course_offerings;
create policy offerings_read on public.course_offerings
  for select to authenticated using (
    batch_id = (select private.current_batch())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy offerings_write on public.course_offerings;
create policy offerings_write on public.course_offerings
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy class_sessions_read on public.class_sessions;
create policy class_sessions_read on public.class_sessions
  for select to authenticated using (
    batch_id = (select private.current_batch())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy class_sessions_write on public.class_sessions;
create policy class_sessions_write on public.class_sessions
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy attendance_read on public.attendance_records;
create policy attendance_read on public.attendance_records
  for select to authenticated using (
    student_id = (select auth.uid())
    or batch_id = (select private.current_batch())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy attendance_write on public.attendance_records;
create policy attendance_write on public.attendance_records
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy attendance_history_read on public.attendance_history;
create policy attendance_history_read on public.attendance_history
  for select to authenticated using (
    exists (
      select 1 from public.attendance_records ar
      where ar.id = attendance_history.record_id
        and (
          ar.student_id = (select auth.uid())
          or ar.batch_id = (select private.current_batch())
          or private.is_cr_of_batch(ar.batch_id)
          or (select private.is_super_admin())
        )
    )
  );

drop policy attendance_corr_read on public.attendance_correction_requests;
create policy attendance_corr_read on public.attendance_correction_requests
  for select to authenticated using (
    student_id = (select auth.uid())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy attendance_corr_insert on public.attendance_correction_requests;
create policy attendance_corr_insert on public.attendance_correction_requests
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and batch_id = (select private.current_batch())
  );
drop policy attendance_corr_cr_update on public.attendance_correction_requests;
create policy attendance_corr_cr_update on public.attendance_correction_requests
  for update to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy schedules_read on public.class_schedules;
create policy schedules_read on public.class_schedules
  for select to authenticated using (
    batch_id = (select private.current_batch())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy schedules_write on public.class_schedules;
create policy schedules_write on public.class_schedules
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy exams_read on public.exams;
create policy exams_read on public.exams
  for select to authenticated using (
    batch_id = (select private.current_batch())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy exams_write on public.exams;
create policy exams_write on public.exams
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy resources_read on public.resources;
create policy resources_read on public.resources
  for select to authenticated using (
    batch_id = (select private.current_batch())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );
drop policy resources_write on public.resources;
create policy resources_write on public.resources
  for all to authenticated
  using (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()))
  with check (private.is_cr_of_batch(batch_id) or (select private.is_super_admin()));

drop policy batch_change_read on public.batch_change_requests;
create policy batch_change_read on public.batch_change_requests
  for select to authenticated using (
    student_id = (select auth.uid())
    or private.is_cr_of_batch(to_batch_id)
    or private.is_cr_of_batch(from_batch_id)
    or (select private.is_super_admin())
  );
drop policy batch_change_insert on public.batch_change_requests;
create policy batch_change_insert on public.batch_change_requests
  for insert to authenticated
  with check (
    student_id = (select auth.uid())
    and from_batch_id = (select private.current_batch())
  );

-- Notices, notifications, audit, services --------------------------------------
drop policy notices_read on public.notices;
create policy notices_read on public.notices
  for select to authenticated using (
    (select private.is_super_admin())
    or (scope = 'university' and state = 'published' and deleted_at is null)
    or (scope = 'batch' and batch_id = (select private.current_batch())
        and state = 'published' and deleted_at is null)
    or (scope = 'batch' and private.is_cr_of_batch(batch_id))
  );
drop policy notices_university_write on public.notices;
create policy notices_university_write on public.notices
  for all to authenticated
  using (scope = 'university' and (select private.is_super_admin()))
  with check (scope = 'university' and (select private.is_super_admin()));
drop policy notices_batch_write on public.notices;
create policy notices_batch_write on public.notices
  for all to authenticated
  using (scope = 'batch' and (private.is_cr_of_batch(batch_id) or (select private.is_super_admin())))
  with check (scope = 'batch' and (private.is_cr_of_batch(batch_id) or (select private.is_super_admin())));

drop policy notice_attachments_read on public.notice_attachments;
create policy notice_attachments_read on public.notice_attachments
  for select to authenticated using (
    exists (
      select 1 from public.notices n
      where n.id = notice_attachments.notice_id
        and (
          (select private.is_super_admin())
          or (n.scope = 'university' and n.state = 'published')
          or (n.scope = 'batch' and n.batch_id = (select private.current_batch()) and n.state = 'published')
          or (n.scope = 'batch' and private.is_cr_of_batch(n.batch_id))
        )
    )
  );
drop policy notice_attachments_write on public.notice_attachments;
create policy notice_attachments_write on public.notice_attachments
  for all to authenticated
  using (
    exists (select 1 from public.notices n where n.id = notice_attachments.notice_id
            and (private.is_cr_of_batch(n.batch_id) or (select private.is_super_admin())))
  )
  with check (
    exists (select 1 from public.notices n where n.id = notice_attachments.notice_id
            and (private.is_cr_of_batch(n.batch_id) or (select private.is_super_admin())))
  );

drop policy notice_reads_author on public.notice_reads;
create policy notice_reads_author on public.notice_reads
  for select to authenticated using (
    exists (select 1 from public.notices n where n.id = notice_reads.notice_id
            and (private.is_cr_of_batch(n.batch_id) or (select private.is_super_admin())))
  );

drop policy audit_read on public.audit_logs;
create policy audit_read on public.audit_logs
  for select to authenticated using ((select private.is_super_admin()));

drop policy bus_routes_admin on public.bus_routes;
create policy bus_routes_admin on public.bus_routes
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

drop policy bus_trips_admin on public.bus_trips;
create policy bus_trips_admin on public.bus_trips
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));

drop policy blood_requests_update on public.blood_requests;
create policy blood_requests_update on public.blood_requests
  for update to authenticated
  using (requester_id = (select auth.uid()) or (select private.is_super_admin()))
  with check (requester_id = (select auth.uid()) or (select private.is_super_admin()));
drop policy blood_requests_delete on public.blood_requests;
create policy blood_requests_delete on public.blood_requests
  for delete to authenticated
  using (requester_id = (select auth.uid()) or (select private.is_super_admin()));

drop policy blood_donors_self on public.blood_donors;
create policy blood_donors_self on public.blood_donors
  for all to authenticated
  using (profile_id = (select auth.uid()) or (select private.is_super_admin()))
  with check (profile_id = (select auth.uid()) or (select private.is_super_admin()));

drop policy lost_found_update on public.lost_found_items;
create policy lost_found_update on public.lost_found_items
  for update to authenticated
  using (reporter_id = (select auth.uid()) or (select private.is_super_admin()))
  with check (reporter_id = (select auth.uid()) or (select private.is_super_admin()));
drop policy lost_found_delete on public.lost_found_items;
create policy lost_found_delete on public.lost_found_items
  for delete to authenticated
  using (reporter_id = (select auth.uid()) or (select private.is_super_admin()));

drop policy alerts_admin on public.alerts;
create policy alerts_admin on public.alerts
  for all to authenticated
  using ((select private.is_super_admin())) with check ((select private.is_super_admin()));
