-- BU Horizon — 13. RLS: notices, notifications, audit, and campus services

-- ===========================================================================
-- Notices (poll Q49)
--   university-scoped published notices → readable by all (poll Q28 public notices)
--   batch-scoped → own batch members + that batch's CR
--   university notices are super-admin-only to write (poll Q49)
--   batch notices are written by the batch CR
-- Draft/scheduled/archived states are only visible to the author-side (CR/admin).
-- ===========================================================================
create policy notices_read on public.notices
  for select to authenticated using (
    private.is_super_admin()
    or (scope = 'university' and state = 'published' and deleted_at is null)
    or (scope = 'batch' and batch_id = private.current_batch()
        and state = 'published' and deleted_at is null)
    or (scope = 'batch' and private.is_cr_of_batch(batch_id))
  );

-- University notices: super admin only.
create policy notices_university_write on public.notices
  for all to authenticated
  using (scope = 'university' and private.is_super_admin())
  with check (scope = 'university' and private.is_super_admin());

-- Batch notices: the batch CR (or super admin).
create policy notices_batch_write on public.notices
  for all to authenticated
  using (scope = 'batch' and (private.is_cr_of_batch(batch_id) or private.is_super_admin()))
  with check (scope = 'batch' and (private.is_cr_of_batch(batch_id) or private.is_super_admin()));

-- Notice attachments — follow the parent notice's visibility/authorship.
create policy notice_attachments_read on public.notice_attachments
  for select to authenticated using (
    exists (
      select 1 from public.notices n
      where n.id = notice_attachments.notice_id
        and (
          private.is_super_admin()
          or (n.scope = 'university' and n.state = 'published')
          or (n.scope = 'batch' and n.batch_id = private.current_batch() and n.state = 'published')
          or (n.scope = 'batch' and private.is_cr_of_batch(n.batch_id))
        )
    )
  );
create policy notice_attachments_write on public.notice_attachments
  for all to authenticated
  using (
    exists (select 1 from public.notices n where n.id = notice_attachments.notice_id
            and (private.is_cr_of_batch(n.batch_id) or private.is_super_admin()))
  )
  with check (
    exists (select 1 from public.notices n where n.id = notice_attachments.notice_id
            and (private.is_cr_of_batch(n.batch_id) or private.is_super_admin()))
  );

-- Notice reads / acknowledgements — a user manages only their own (poll Q57).
create policy notice_reads_self on public.notice_reads
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
-- CR/admin may read receipts for their notices (read confirmation, poll Q51).
create policy notice_reads_author on public.notice_reads
  for select to authenticated using (
    exists (select 1 from public.notices n where n.id = notice_reads.notice_id
            and (private.is_cr_of_batch(n.batch_id) or private.is_super_admin()))
  );

-- ===========================================================================
-- Notifications — recipient reads/updates own; inserts server-side only.
-- No client INSERT policy: notifications are created by triggers/edge functions
-- (SECURITY DEFINER / service role). Recipients may mark read (poll Q57).
-- ===========================================================================
create policy notifications_read on public.notifications
  for select to authenticated using (recipient_id = (select auth.uid()));
create policy notifications_update on public.notifications
  for update to authenticated
  using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));

-- ===========================================================================
-- Audit logs (poll Q58) — super admin reads; no client writes (server-side /
-- SECURITY DEFINER functions insert). Immutability enforced by trigger too.
-- ===========================================================================
create policy audit_read on public.audit_logs
  for select to authenticated using (private.is_super_admin());

-- ===========================================================================
-- Campus services
-- ===========================================================================

-- Bus routes/trips: readable by all authenticated; super admin manages.
create policy bus_routes_read on public.bus_routes
  for select to authenticated using (true);
create policy bus_routes_admin on public.bus_routes
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

create policy bus_trips_read on public.bus_trips
  for select to authenticated using (true);
create policy bus_trips_admin on public.bus_trips
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());

-- Bus favorites: each user manages their own.
create policy bus_favorites_self on public.bus_route_favorites
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));

-- Blood requests: readable by all; author (or admin) manages their post.
create policy blood_requests_read on public.blood_requests
  for select to authenticated using (true);
create policy blood_requests_insert on public.blood_requests
  for insert to authenticated
  with check (requester_id = (select auth.uid()));
create policy blood_requests_update on public.blood_requests
  for update to authenticated
  using (requester_id = (select auth.uid()) or private.is_super_admin())
  with check (requester_id = (select auth.uid()) or private.is_super_admin());
create policy blood_requests_delete on public.blood_requests
  for delete to authenticated
  using (requester_id = (select auth.uid()) or private.is_super_admin());

-- Blood donors: directory readable by all; each user manages their own listing.
create policy blood_donors_read on public.blood_donors
  for select to authenticated using (true);
create policy blood_donors_self on public.blood_donors
  for all to authenticated
  using (profile_id = (select auth.uid()) or private.is_super_admin())
  with check (profile_id = (select auth.uid()) or private.is_super_admin());

-- Lost & found: readable by all; author (or admin) manages their post.
create policy lost_found_read on public.lost_found_items
  for select to authenticated using (true);
create policy lost_found_insert on public.lost_found_items
  for insert to authenticated
  with check (reporter_id = (select auth.uid()));
create policy lost_found_update on public.lost_found_items
  for update to authenticated
  using (reporter_id = (select auth.uid()) or private.is_super_admin())
  with check (reporter_id = (select auth.uid()) or private.is_super_admin());
create policy lost_found_delete on public.lost_found_items
  for delete to authenticated
  using (reporter_id = (select auth.uid()) or private.is_super_admin());

-- Alerts: readable by all; super admin (or CR-generated via server) writes.
create policy alerts_read on public.alerts
  for select to authenticated using (true);
create policy alerts_admin on public.alerts
  for all to authenticated
  using (private.is_super_admin()) with check (private.is_super_admin());
