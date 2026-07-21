-- BU Horizon — 10. Views
-- All views use security_invoker so the caller's RLS applies (Postgres 15+).

-- ---------------------------------------------------------------------------
-- People directory — university-wide (name, department, email only).
-- People Search returns students across departments (decision: university-wide
-- directory), while academic content stays batch/department-isolated via RLS.
--
-- This view is intentionally SECURITY DEFINER (the default, security_invoker
-- off): the base profiles RLS restricts a student to their own row, so an
-- invoker view would return nothing. Bypassing RLS here is safe because the
-- view exposes ONLY the three non-sensitive directory columns (name, email,
-- department) and filters to active, non-deleted users. Access is then locked
-- to authenticated users via GRANT below.
-- ---------------------------------------------------------------------------
create view public.people_directory as
  select
    p.id,
    p.full_name,
    p.email,
    d.name  as department_name,
    d.code  as department_code,
    f.name  as faculty_name
  from public.profiles p
  left join public.departments d on d.id = p.department_id
  left join public.faculties f on f.id = d.faculty_id
  where p.status = 'active' and p.deleted_at is null;

-- Only authenticated users may read the directory; revoke the implicit anon grant.
revoke all on public.people_directory from anon;
grant select on public.people_directory to authenticated;

-- ---------------------------------------------------------------------------
-- Class schedule conflicts (poll Q46): room double-booking across batches on
-- the same date and overlapping time. This is exposed as a SECURITY DEFINER
-- function rather than a view because detection must cross batch boundaries —
-- an invoker view would hide the other batch's row (poll Q29 isolation) and no
-- conflict would ever surface. To respect isolation, the function returns only
-- the caller's own schedule row plus the conflict slot and the OTHER batch's CR
-- contact (name/phone/email) so the two CRs can coordinate — never the other
-- batch's full schedule content. Scoped to the caller's batch; callable by that
-- batch's CR or a super admin only.
-- ---------------------------------------------------------------------------
create or replace function public.get_schedule_conflicts(target_batch uuid)
returns table (
  my_schedule_id        uuid,
  schedule_date         date,
  room                  text,
  start_time            time,
  end_time              time,
  conflicting_batch_id  uuid,
  conflicting_cr_name   text,
  conflicting_cr_phone  text,
  conflicting_cr_email  text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    a.id, a.schedule_date, a.room, a.start_time, a.end_time,
    b.batch_id,
    cr.full_name, cr.phone, cr.email::text
  from public.class_schedules a
  join public.class_schedules b
    on b.batch_id <> a.batch_id
   and a.schedule_date = b.schedule_date
   and a.room is not null and a.room = b.room
   and a.type <> 'cancelled' and b.type <> 'cancelled'
   and a.deleted_at is null and b.deleted_at is null
   and a.start_time < b.end_time and b.start_time < a.end_time
  left join public.cr_assignments ca on ca.batch_id = b.batch_id
  left join public.profiles cr on cr.id = ca.profile_id
  where a.batch_id = target_batch
    and (private.is_cr_of_batch(target_batch) or private.is_super_admin());
$$;

revoke all on function public.get_schedule_conflicts(uuid) from public;
grant execute on function public.get_schedule_conflicts(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Attendance summary per student per offering (poll Q43: percentage,
-- course-wise). Percentages/shortage lists are computed client- or report-side
-- from this base view.
-- ---------------------------------------------------------------------------
create view public.attendance_summary
with (security_invoker = true) as
  select
    ar.student_id,
    cs.offering_id,
    co.batch_id,
    count(*)                                             as total_classes,
    count(*) filter (where ar.status = 'present')        as present_count,
    round(
      100.0 * count(*) filter (where ar.status = 'present')
      / nullif(count(*), 0), 2)                          as attendance_percentage
  from public.attendance_records ar
  join public.class_sessions cs on cs.id = ar.session_id
  join public.course_offerings co on co.id = cs.offering_id
  group by ar.student_id, cs.offering_id, co.batch_id;
