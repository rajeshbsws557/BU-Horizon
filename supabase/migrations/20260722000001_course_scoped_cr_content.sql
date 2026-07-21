-- BU Horizon - course-scoped CR content
--
-- A course catalogue row belongs to a department; a course_offering is that
-- course as taught to one batch.  Student-facing course lists and all class
-- content therefore use course_offerings as their security boundary.

-- ---------------------------------------------------------------------------
-- Course linkage and useful actor defaults
-- ---------------------------------------------------------------------------

alter table public.notices
  add column if not exists offering_id uuid
    references public.course_offerings (id) on delete set null;

alter table public.notices
  drop constraint if exists chk_notice_offering_scope;
alter table public.notices
  add constraint chk_notice_offering_scope
  check (offering_id is null or (scope = 'batch' and batch_id is not null));

create index if not exists idx_notices_offering_published
  on public.notices (offering_id, published_at desc)
  where offering_id is not null and deleted_at is null;

create index if not exists idx_resources_offering_created
  on public.resources (offering_id, created_at desc)
  where offering_id is not null and deleted_at is null;

create index if not exists idx_offerings_batch_active
  on public.course_offerings (batch_id, term_number, created_at)
  where deleted_at is null;

alter table public.notices
  alter column created_by set default auth.uid();
alter table public.resources
  alter column created_by set default auth.uid();
alter table public.class_sessions
  alter column created_by set default auth.uid();
alter table public.attendance_records
  alter column recorded_by set default auth.uid();

comment on column public.notices.offering_id is
  'Course offering for a class notice. NULL preserves university notices and legacy batch-wide notices.';

-- ---------------------------------------------------------------------------
-- Authorization helpers
-- ---------------------------------------------------------------------------

-- Reassert the privileged-role invariants here as well as in the admin-panel
-- migration.  This keeps the content boundary safe if environments apply this
-- feature migration while an earlier admin migration is still pending.
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
    join public.programs pg on pg.id = b.program_id
    where ca.profile_id = (select auth.uid())
      and pr.batch_id = ca.batch_id
      and pr.role = 'cr'::public.user_role
      and pr.status = 'active'::public.profile_status
      and pr.deleted_at is null
      and pg.department_id = target_department
  );
$$;

create or replace function private.is_active_batch_member(target_batch uuid)
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
      and p.batch_id = target_batch
      and p.role in ('student'::public.user_role, 'cr'::public.user_role)
      and p.status = 'active'::public.profile_status
      and p.deleted_at is null
  );
$$;

-- Returns at most one row and is intentionally private.  Public CR RPCs use
-- it to derive their batch/department instead of trusting client-supplied IDs.
create or replace function private.current_cr_context()
returns table (
  profile_id uuid,
  batch_id uuid,
  department_id uuid,
  current_term smallint
)
language sql
stable
security definer
set search_path = ''
as $$
  select pr.id, ca.batch_id, pg.department_id, b.current_term
  from public.cr_assignments ca
  join public.profiles pr on pr.id = ca.profile_id
  join public.batches b on b.id = ca.batch_id
  join public.programs pg on pg.id = b.program_id
  where ca.profile_id = (select auth.uid())
    and pr.batch_id = ca.batch_id
    and pr.role = 'cr'::public.user_role
    and pr.status = 'active'::public.profile_status
    and pr.deleted_at is null
  limit 1;
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

revoke all on function private.is_active_batch_member(uuid) from public;
revoke all on function private.is_active_batch_member(uuid) from anon;
grant execute on function private.is_active_batch_member(uuid) to authenticated;
revoke all on function private.current_cr_context() from public;
revoke all on function private.current_cr_context() from anon;

-- ---------------------------------------------------------------------------
-- Cross-table integrity.  RLS checks the denormalized batch_id; these triggers
-- make sure it can never disagree with the referenced offering/session.
-- ---------------------------------------------------------------------------

create or replace function private.enforce_offering_department()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  course_department uuid;
  batch_department uuid;
begin
  select c.department_id
    into course_department
    from public.courses c
   where c.id = new.course_id;

  select pg.department_id
    into batch_department
    from public.batches b
    join public.programs pg on pg.id = b.program_id
   where b.id = new.batch_id;

  if course_department is null or batch_department is null then
    raise exception using
      errcode = '23503',
      message = 'Course offering references an unknown course or batch.';
  end if;

  if course_department is distinct from batch_department then
    raise exception using
      errcode = '23514',
      message = 'A course offering must use a course from the batch department.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_offerings_department_guard
  on public.course_offerings;
create trigger trg_offerings_department_guard
  before insert or update of course_id, batch_id
  on public.course_offerings
  for each row execute function private.enforce_offering_department();

create or replace function private.enforce_notice_offering_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  offering_batch uuid;
begin
  if new.offering_id is null then
    return new;
  end if;

  select co.batch_id
    into offering_batch
    from public.course_offerings co
   where co.id = new.offering_id;

  if offering_batch is null then
    raise exception using
      errcode = '23503',
      message = 'Notice references an unknown course offering.';
  end if;

  if new.scope <> 'batch'::public.notice_scope
     or new.batch_id is distinct from offering_batch then
    raise exception using
      errcode = '23514',
      message = 'A class notice and its course offering must belong to the same batch.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notices_offering_batch_guard on public.notices;
create trigger trg_notices_offering_batch_guard
  before insert or update of scope, batch_id, offering_id
  on public.notices
  for each row execute function private.enforce_notice_offering_batch();

create or replace function private.enforce_resource_offering_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  offering_batch uuid;
begin
  if new.offering_id is null then
    return new;
  end if;

  select co.batch_id
    into offering_batch
    from public.course_offerings co
   where co.id = new.offering_id;

  if offering_batch is null then
    raise exception using
      errcode = '23503',
      message = 'Resource references an unknown course offering.';
  end if;

  if new.batch_id is distinct from offering_batch then
    raise exception using
      errcode = '23514',
      message = 'A resource and its course offering must belong to the same batch.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_resources_offering_batch_guard on public.resources;
create trigger trg_resources_offering_batch_guard
  before insert or update of batch_id, offering_id
  on public.resources
  for each row execute function private.enforce_resource_offering_batch();

create or replace function private.enforce_session_offering_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  offering_batch uuid;
begin
  select co.batch_id
    into offering_batch
    from public.course_offerings co
   where co.id = new.offering_id;

  if offering_batch is null then
    raise exception using
      errcode = '23503',
      message = 'Class session references an unknown course offering.';
  end if;

  if new.batch_id is distinct from offering_batch then
    raise exception using
      errcode = '23514',
      message = 'A class session and its course offering must belong to the same batch.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sessions_offering_batch_guard
  on public.class_sessions;
create trigger trg_sessions_offering_batch_guard
  before insert or update of offering_id, batch_id
  on public.class_sessions
  for each row execute function private.enforce_session_offering_batch();

create or replace function private.enforce_attendance_session_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  session_batch uuid;
  student_batch uuid;
  student_is_active boolean;
begin
  select cs.batch_id
    into session_batch
    from public.class_sessions cs
   where cs.id = new.session_id;

  if session_batch is null then
    raise exception using
      errcode = '23503',
      message = 'Attendance record references an unknown class session.';
  end if;

  if new.batch_id is distinct from session_batch then
    raise exception using
      errcode = '23514',
      message = 'An attendance record and its class session must belong to the same batch.';
  end if;

  -- A later batch transfer must not make historical status edits impossible.
  -- Membership is therefore checked when a record/student/batch is assigned,
  -- but not when an existing historical row only changes status.
  if tg_op = 'INSERT'
     or new.student_id is distinct from old.student_id
     or new.batch_id is distinct from old.batch_id then
    select p.batch_id,
           p.status = 'active'::public.profile_status
             and p.deleted_at is null
             and p.role in ('student'::public.user_role, 'cr'::public.user_role)
      into student_batch, student_is_active
      from public.profiles p
     where p.id = new.student_id;

    if student_batch is null then
      raise exception using
        errcode = '23503',
        message = 'Attendance record references an unknown student.';
    end if;

    if not student_is_active or student_batch is distinct from new.batch_id then
      raise exception using
        errcode = '23514',
        message = 'Attendance can only be recorded for an active member of the class batch.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_attendance_session_batch_guard
  on public.attendance_records;
create trigger trg_attendance_session_batch_guard
  before insert or update of session_id, student_id, batch_id
  on public.attendance_records
  for each row execute function private.enforce_attendance_session_batch();

revoke all on function private.enforce_offering_department() from public;
revoke all on function private.enforce_notice_offering_batch() from public;
revoke all on function private.enforce_resource_offering_batch() from public;
revoke all on function private.enforce_session_offering_batch() from public;
revoke all on function private.enforce_attendance_session_batch() from public;

-- Refuse to claim the stronger invariant if legacy data already violates it.
do $$
begin
  if exists (
    select 1
    from public.course_offerings co
    join public.courses c on c.id = co.course_id
    join public.batches b on b.id = co.batch_id
    join public.programs pg on pg.id = b.program_id
    where c.department_id is distinct from pg.department_id
  ) then
    raise exception 'Existing course offering belongs to a different department than its batch.';
  end if;

  if exists (
    select 1
    from public.notices n
    join public.course_offerings co on co.id = n.offering_id
    where n.scope <> 'batch'::public.notice_scope
       or n.batch_id is distinct from co.batch_id
  ) then
    raise exception 'Existing class notice has a mismatched course offering.';
  end if;

  if exists (
    select 1
    from public.resources r
    join public.course_offerings co on co.id = r.offering_id
    where r.batch_id is distinct from co.batch_id
  ) then
    raise exception 'Existing resource has a mismatched course offering.';
  end if;

  if exists (
    select 1
    from public.class_sessions cs
    join public.course_offerings co on co.id = cs.offering_id
    where cs.batch_id is distinct from co.batch_id
  ) then
    raise exception 'Existing class session has a mismatched course offering.';
  end if;

  if exists (
    select 1
    from public.attendance_records ar
    join public.class_sessions cs on cs.id = ar.session_id
    where ar.batch_id is distinct from cs.batch_id
  ) then
    raise exception 'Existing attendance record has a mismatched class session.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Student-facing course list
-- ---------------------------------------------------------------------------

create or replace view public.batch_courses
with (security_invoker = true) as
  select
    co.id as offering_id,
    co.batch_id,
    c.id as course_id,
    c.department_id,
    c.code,
    c.title,
    c.title_bn,
    c.credit_hours,
    co.term_number,
    co.teacher_name,
    co.created_at,
    co.updated_at
  from public.course_offerings co
  join public.courses c on c.id = co.course_id
  where co.deleted_at is null
    and c.deleted_at is null;

revoke all on public.batch_courses from public;
revoke all on public.batch_courses from anon;
grant select on public.batch_courses to authenticated;

comment on view public.batch_courses is
  'Active course offerings visible through the caller RLS; this is the course-first entry point for notices, resources, and attendance.';

-- The former base-table policy exposed every profile column to a CR.  The
-- narrowly validated roster RPC below is now the supported lookup surface.
drop policy if exists profiles_cr_read_batch on public.profiles;

-- ---------------------------------------------------------------------------
-- Tightened RLS: active students read their cohort; CRs write only their own
-- cohort.  Soft-deleted course/content rows stay available to CR/admin for
-- restore/audit but are invisible to regular students.
-- ---------------------------------------------------------------------------

drop policy if exists offerings_read on public.course_offerings;
drop policy if exists offerings_write on public.course_offerings;
drop policy if exists offerings_cr_insert on public.course_offerings;
drop policy if exists offerings_cr_update on public.course_offerings;
drop policy if exists offerings_admin_all on public.course_offerings;
drop policy if exists offerings_admin_delete on public.course_offerings;

create policy offerings_read on public.course_offerings
  for select to authenticated
  using (
    (select private.is_super_admin())
    or private.is_cr_of_batch(batch_id)
    or (
      private.is_active_batch_member(batch_id)
      and deleted_at is null
      and exists (
        select 1 from public.courses c
        where c.id = course_id and c.deleted_at is null
      )
    )
  );

create policy offerings_cr_insert on public.course_offerings
  for insert to authenticated
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy offerings_cr_update on public.course_offerings
  for update to authenticated
  using (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  )
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy offerings_admin_delete on public.course_offerings
  for delete to authenticated
  using ((select private.is_super_admin()));

-- New catalogue rows must be made through create_batch_course(), which also
-- creates the caller's offering atomically.  Existing super-admin policy stays.
drop policy if exists courses_cr_insert on public.courses;
drop policy if exists courses_cr_update on public.courses;

drop policy if exists class_sessions_read on public.class_sessions;
drop policy if exists class_sessions_write on public.class_sessions;
drop policy if exists class_sessions_cr_write on public.class_sessions;
drop policy if exists class_sessions_admin_all on public.class_sessions;
drop policy if exists class_sessions_insert on public.class_sessions;
drop policy if exists class_sessions_update on public.class_sessions;
drop policy if exists class_sessions_delete on public.class_sessions;

create policy class_sessions_read on public.class_sessions
  for select to authenticated
  using (
    (select private.is_super_admin())
    or private.is_cr_of_batch(batch_id)
    or (
      private.is_active_batch_member(batch_id)
      and deleted_at is null
      and exists (
        select 1
        from public.course_offerings co
        join public.courses c on c.id = co.course_id
        where co.id = offering_id
          and co.batch_id = class_sessions.batch_id
          and co.deleted_at is null
          and c.deleted_at is null
      )
    )
  );

create policy class_sessions_insert on public.class_sessions
  for insert to authenticated
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy class_sessions_update on public.class_sessions
  for update to authenticated
  using (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  )
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy class_sessions_delete on public.class_sessions
  for delete to authenticated
  using (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

drop policy if exists resources_read on public.resources;
drop policy if exists resources_write on public.resources;
drop policy if exists resources_cr_insert on public.resources;
drop policy if exists resources_cr_update on public.resources;
drop policy if exists resources_admin_all on public.resources;
drop policy if exists resources_admin_delete on public.resources;

create policy resources_read on public.resources
  for select to authenticated
  using (
    (select private.is_super_admin())
    or private.is_cr_of_batch(batch_id)
    or (
      private.is_active_batch_member(batch_id)
      and deleted_at is null
      and (
        offering_id is null
        or exists (
          select 1
          from public.course_offerings co
          join public.courses c on c.id = co.course_id
          where co.id = offering_id
            and co.batch_id = resources.batch_id
            and co.deleted_at is null
            and c.deleted_at is null
        )
      )
    )
  );

create policy resources_cr_insert on public.resources
  for insert to authenticated
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy resources_cr_update on public.resources
  for update to authenticated
  using (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  )
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy resources_admin_delete on public.resources
  for delete to authenticated
  using ((select private.is_super_admin()));

drop policy if exists notices_read on public.notices;
drop policy if exists notices_university_write on public.notices;
drop policy if exists notices_batch_write on public.notices;
drop policy if exists notices_batch_cr_insert on public.notices;
drop policy if exists notices_batch_cr_update on public.notices;
drop policy if exists notices_admin_all on public.notices;
drop policy if exists notices_admin_delete on public.notices;

create policy notices_read on public.notices
  for select to authenticated
  using (
    (select private.is_super_admin())
    or (
      scope = 'university'::public.notice_scope
      and state = 'published'::public.notice_state
      and deleted_at is null
    )
    or (
      scope = 'batch'::public.notice_scope
      and private.is_cr_of_batch(batch_id)
    )
    or (
      scope = 'batch'::public.notice_scope
      and private.is_active_batch_member(batch_id)
      and state = 'published'::public.notice_state
      and deleted_at is null
      and (
        offering_id is null
        or exists (
          select 1
          from public.course_offerings co
          join public.courses c on c.id = co.course_id
          where co.id = offering_id
            and co.batch_id = notices.batch_id
            and co.deleted_at is null
            and c.deleted_at is null
        )
      )
    )
  );

create policy notices_batch_cr_insert on public.notices
  for insert to authenticated
  with check (
    (select private.is_super_admin())
    or (
      scope = 'batch'::public.notice_scope
      and private.is_cr_of_batch(batch_id)
    )
  );

create policy notices_batch_cr_update on public.notices
  for update to authenticated
  using (
    (select private.is_super_admin())
    or (
      scope = 'batch'::public.notice_scope
      and private.is_cr_of_batch(batch_id)
    )
  )
  with check (
    (select private.is_super_admin())
    or (
      scope = 'batch'::public.notice_scope
      and private.is_cr_of_batch(batch_id)
    )
  );

create policy notices_admin_delete on public.notices
  for delete to authenticated
  using ((select private.is_super_admin()));

-- Attendance privacy is deliberately reasserted here: a normal student never
-- receives another student's row, even if both share a batch.
drop policy if exists attendance_read on public.attendance_records;
drop policy if exists attendance_write on public.attendance_records;
drop policy if exists attendance_cr_write on public.attendance_records;
drop policy if exists attendance_admin_all on public.attendance_records;
drop policy if exists attendance_insert on public.attendance_records;
drop policy if exists attendance_update on public.attendance_records;
drop policy if exists attendance_delete on public.attendance_records;

create policy attendance_read on public.attendance_records
  for select to authenticated
  using (
    student_id = (select auth.uid())
    or private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy attendance_insert on public.attendance_records
  for insert to authenticated
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy attendance_update on public.attendance_records
  for update to authenticated
  using (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  )
  with check (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

create policy attendance_delete on public.attendance_records
  for delete to authenticated
  using (
    private.is_cr_of_batch(batch_id)
    or (select private.is_super_admin())
  );

drop policy if exists attendance_history_read on public.attendance_history;
create policy attendance_history_read on public.attendance_history
  for select to authenticated
  using (
    exists (
      select 1
      from public.attendance_records ar
      where ar.id = attendance_history.record_id
        and (
          ar.student_id = (select auth.uid())
          or private.is_cr_of_batch(ar.batch_id)
          or (select private.is_super_admin())
        )
    )
  );

-- ---------------------------------------------------------------------------
-- Atomic CR course/offering workflows
-- ---------------------------------------------------------------------------

create or replace function public.create_batch_course(
  p_code text,
  p_title text,
  p_credit_hours numeric default null,
  p_term_number smallint default null,
  p_teacher_name text default null,
  p_title_bn text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ctx record;
  target_course public.courses%rowtype;
  target_offering public.course_offerings%rowtype;
  normalized_code text;
  normalized_title text;
  effective_term smallint;
begin
  select * into ctx from private.current_cr_context();
  if not found then
    raise exception using
      errcode = '42501',
      message = 'Only an active CR can add a course to their batch.';
  end if;

  normalized_code := upper(btrim(p_code));
  normalized_title := btrim(p_title);
  if coalesce(normalized_code, '') = '' or coalesce(normalized_title, '') = '' then
    raise exception using
      errcode = '22023',
      message = 'Course code and title are required.';
  end if;

  effective_term := coalesce(p_term_number, ctx.current_term);
  if effective_term is null or effective_term < 1 then
    raise exception using
      errcode = '22023',
      message = 'Course term number must be at least 1.';
  end if;
  if p_credit_hours is not null and p_credit_hours < 0 then
    raise exception using
      errcode = '22023',
      message = 'Credit hours cannot be negative.';
  end if;

  -- Serializes both same-batch saves and same-code catalogue creation across
  -- different batches in the department.
  perform 1 from public.batches b where b.id = ctx.batch_id for update;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(ctx.department_id::text || ':' || normalized_code, 0)
  );

  select c.*
    into target_course
    from public.courses c
   where c.department_id = ctx.department_id
     and upper(btrim(c.code)) = normalized_code
   order by c.created_at
   limit 1
   for update;

  if found then
    if target_course.deleted_at is not null then
      raise exception using
        errcode = '55000',
        message = 'That course code is archived; ask an administrator to restore it.';
    end if;
  else
    insert into public.courses (
      department_id, code, title, title_bn, credit_hours, term_number
    ) values (
      ctx.department_id,
      normalized_code,
      normalized_title,
      nullif(btrim(p_title_bn), ''),
      p_credit_hours,
      effective_term
    )
    returning * into target_course;
  end if;

  select co.*
    into target_offering
    from public.course_offerings co
   where co.course_id = target_course.id
     and co.batch_id = ctx.batch_id
     and co.term_number = effective_term
   for update;

  if found then
    update public.course_offerings co
       set teacher_name = nullif(btrim(p_teacher_name), ''),
           deleted_at = null,
           updated_at = now()
     where co.id = target_offering.id
     returning co.* into target_offering;
  else
    insert into public.course_offerings (
      course_id, batch_id, term_number, teacher_name
    ) values (
      target_course.id,
      ctx.batch_id,
      effective_term,
      nullif(btrim(p_teacher_name), '')
    )
    returning * into target_offering;
  end if;

  return jsonb_build_object(
    'offering_id', target_offering.id,
    'course_id', target_course.id,
    'batch_id', target_offering.batch_id,
    'department_id', target_course.department_id,
    'code', target_course.code,
    'title', target_course.title,
    'title_bn', target_course.title_bn,
    'credit_hours', target_course.credit_hours,
    'term_number', target_offering.term_number,
    'teacher_name', target_offering.teacher_name,
    'deleted_at', target_offering.deleted_at
  );
end;
$$;

create or replace function public.update_batch_course(
  p_offering_id uuid,
  p_code text,
  p_title text,
  p_credit_hours numeric default null,
  p_term_number smallint default null,
  p_teacher_name text default null,
  p_title_bn text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ctx record;
  target_course public.courses%rowtype;
  target_offering public.course_offerings%rowtype;
  normalized_code text;
  normalized_title text;
  effective_term smallint;
  shared_with_other_batch boolean;
begin
  select * into ctx from private.current_cr_context();
  if not found then
    raise exception using
      errcode = '42501',
      message = 'Only an active CR can update a batch course.';
  end if;

  select co.*
    into target_offering
    from public.course_offerings co
   where co.id = p_offering_id
   for update;

  if not found or target_offering.batch_id <> ctx.batch_id then
    raise exception using
      errcode = '42501',
      message = 'The course offering does not belong to the CR batch.';
  end if;

  select c.*
    into strict target_course
    from public.courses c
   where c.id = target_offering.course_id
   for update;

  if target_course.department_id <> ctx.department_id then
    raise exception using
      errcode = '23514',
      message = 'The course does not belong to the CR department.';
  end if;

  normalized_code := upper(btrim(p_code));
  normalized_title := btrim(p_title);
  effective_term := coalesce(p_term_number, target_offering.term_number);

  if coalesce(normalized_code, '') = '' or coalesce(normalized_title, '') = '' then
    raise exception using
      errcode = '22023',
      message = 'Course code and title are required.';
  end if;
  if effective_term < 1 then
    raise exception using
      errcode = '22023',
      message = 'Course term number must be at least 1.';
  end if;
  if p_credit_hours is not null and p_credit_hours < 0 then
    raise exception using
      errcode = '22023',
      message = 'Credit hours cannot be negative.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(ctx.department_id::text || ':' || normalized_code, 0)
  );

  if exists (
    select 1
    from public.courses c
    where c.department_id = ctx.department_id
      and c.id <> target_course.id
      and upper(btrim(c.code)) = normalized_code
  ) then
    raise exception using
      errcode = '23505',
      message = 'Another course already uses that code in this department.';
  end if;

  select exists (
    select 1
    from public.course_offerings co
    where co.course_id = target_course.id
      and co.batch_id <> ctx.batch_id
      and co.deleted_at is null
  ) into shared_with_other_batch;

  if shared_with_other_batch and (
    target_course.code is distinct from normalized_code
    or target_course.title is distinct from normalized_title
    or target_course.title_bn is distinct from nullif(btrim(p_title_bn), '')
    or target_course.credit_hours is distinct from p_credit_hours
    or target_course.term_number is distinct from effective_term
  ) then
    raise exception using
      errcode = '55000',
      message = 'Shared course metadata cannot be changed by one batch CR; only the teacher can be changed.';
  end if;

  update public.courses c
     set code = normalized_code,
         title = normalized_title,
         title_bn = nullif(btrim(p_title_bn), ''),
         credit_hours = p_credit_hours,
         term_number = effective_term,
         updated_at = now()
   where c.id = target_course.id
   returning c.* into target_course;

  update public.course_offerings co
     set term_number = effective_term,
         teacher_name = nullif(btrim(p_teacher_name), ''),
         updated_at = now()
   where co.id = target_offering.id
   returning co.* into target_offering;

  return jsonb_build_object(
    'offering_id', target_offering.id,
    'course_id', target_course.id,
    'batch_id', target_offering.batch_id,
    'department_id', target_course.department_id,
    'code', target_course.code,
    'title', target_course.title,
    'title_bn', target_course.title_bn,
    'credit_hours', target_course.credit_hours,
    'term_number', target_offering.term_number,
    'teacher_name', target_offering.teacher_name,
    'deleted_at', target_offering.deleted_at
  );
end;
$$;

create or replace function public.delete_batch_course(p_offering_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ctx record;
  target_course public.courses%rowtype;
  target_offering public.course_offerings%rowtype;
begin
  select * into ctx from private.current_cr_context();
  if not found then
    raise exception using
      errcode = '42501',
      message = 'Only an active CR can remove a batch course.';
  end if;

  select co.*
    into target_offering
    from public.course_offerings co
   where co.id = p_offering_id
   for update;

  if not found or target_offering.batch_id <> ctx.batch_id then
    raise exception using
      errcode = '42501',
      message = 'The course offering does not belong to the CR batch.';
  end if;

  select c.*
    into strict target_course
    from public.courses c
   where c.id = target_offering.course_id;

  update public.course_offerings co
     set deleted_at = coalesce(co.deleted_at, now()),
         updated_at = now()
   where co.id = target_offering.id
   returning co.* into target_offering;

  return jsonb_build_object(
    'offering_id', target_offering.id,
    'course_id', target_course.id,
    'batch_id', target_offering.batch_id,
    'code', target_course.code,
    'title', target_course.title,
    'credit_hours', target_course.credit_hours,
    'term_number', target_offering.term_number,
    'teacher_name', target_offering.teacher_name,
    'deleted_at', target_offering.deleted_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Privacy-limited roster and atomic class-session + attendance upsert
-- ---------------------------------------------------------------------------

create or replace function public.get_batch_attendance_roster(p_offering_id uuid)
returns table (
  profile_id uuid,
  full_name text,
  roll text,
  student_id text,
  role public.user_role
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  ctx record;
  target_offering public.course_offerings%rowtype;
begin
  select * into ctx from private.current_cr_context();
  if not found then
    raise exception using
      errcode = '42501',
      message = 'Only an active CR can read a batch attendance roster.';
  end if;

  select co.*
    into target_offering
    from public.course_offerings co
    join public.courses c on c.id = co.course_id
   where co.id = p_offering_id
     and co.deleted_at is null
     and c.deleted_at is null;

  if not found or target_offering.batch_id <> ctx.batch_id then
    raise exception using
      errcode = '42501',
      message = 'The course offering does not belong to the CR batch.';
  end if;

  return query
    select p.id, p.full_name, p.roll, p.student_id, p.role
    from public.profiles p
    where p.batch_id = target_offering.batch_id
      and p.status = 'active'::public.profile_status
      and p.deleted_at is null
      and p.role in ('student'::public.user_role, 'cr'::public.user_role)
    order by p.roll nulls last, p.full_name, p.id;
end;
$$;

create or replace function public.cr_save_attendance(
  p_offering_id uuid,
  p_session_date date,
  p_records jsonb,
  p_session_id uuid default null,
  p_start_time time default null,
  p_end_time time default null,
  p_topic text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  ctx record;
  target_offering public.course_offerings%rowtype;
  target_session public.class_sessions%rowtype;
  input_count integer;
  total_count integer;
begin
  select * into ctx from private.current_cr_context();
  if not found then
    raise exception using
      errcode = '42501',
      message = 'Only an active CR can record attendance.';
  end if;

  if p_session_date is null then
    raise exception using
      errcode = '22023',
      message = 'Class session date is required.';
  end if;
  if p_start_time is not null and p_end_time is not null
     and p_end_time <= p_start_time then
    raise exception using
      errcode = '22023',
      message = 'Class session end time must be after its start time.';
  end if;
  if p_records is null or jsonb_typeof(p_records) <> 'array' then
    raise exception using
      errcode = '22023',
      message = 'Attendance records must be a JSON array.';
  end if;

  select co.*
    into target_offering
    from public.course_offerings co
    join public.courses c on c.id = co.course_id
   where co.id = p_offering_id
     and co.deleted_at is null
     and c.deleted_at is null
   for update of co;

  if not found or target_offering.batch_id <> ctx.batch_id then
    raise exception using
      errcode = '42501',
      message = 'Attendance can only be saved for an active course in the CR batch.';
  end if;

  input_count := jsonb_array_length(p_records);

  if exists (
    select 1
    from jsonb_array_elements(p_records) item
    where jsonb_typeof(item) <> 'object'
       or coalesce(item ->> 'student_id', '') !~*
          '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       or coalesce(item ->> 'status', '') not in ('present', 'absent')
  ) then
    raise exception using
      errcode = '22023',
      message = 'Each attendance item needs a valid student_id and present/absent status.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_records) item
    group by (item ->> 'student_id')
    having count(*) > 1
  ) then
    raise exception using
      errcode = '22023',
      message = 'Attendance records contain a duplicate student.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_records) item
    left join public.profiles p
      on p.id = (item ->> 'student_id')::uuid
    where p.id is null
       or p.batch_id is distinct from target_offering.batch_id
       or p.status <> 'active'::public.profile_status
       or p.deleted_at is not null
       or p.role not in ('student'::public.user_role, 'cr'::public.user_role)
  ) then
    raise exception using
      errcode = '23514',
      message = 'Attendance includes a user who is not an active member of this batch.';
  end if;

  if p_session_id is not null then
    select cs.*
      into target_session
      from public.class_sessions cs
     where cs.id = p_session_id
     for update;

    if not found
       or target_session.offering_id <> target_offering.id
       or target_session.batch_id <> target_offering.batch_id then
      raise exception using
        errcode = '42501',
        message = 'The class session does not belong to this course offering.';
    end if;

    update public.class_sessions cs
       set session_date = p_session_date,
           start_time = p_start_time,
           end_time = p_end_time,
           topic = nullif(btrim(p_topic), ''),
           deleted_at = null,
           updated_at = now()
     where cs.id = target_session.id
     returning cs.* into target_session;
  else
    -- The offering row lock serializes this lookup, including NULL start_time,
    -- which a normal UNIQUE constraint considers distinct.
    select cs.*
      into target_session
      from public.class_sessions cs
     where cs.offering_id = target_offering.id
       and cs.session_date = p_session_date
       and cs.start_time is not distinct from p_start_time
     order by (cs.deleted_at is null) desc, cs.created_at
     limit 1
     for update;

    if found then
      update public.class_sessions cs
         set end_time = p_end_time,
             topic = nullif(btrim(p_topic), ''),
             deleted_at = null,
             updated_at = now()
       where cs.id = target_session.id
       returning cs.* into target_session;
    else
      insert into public.class_sessions (
        offering_id,
        batch_id,
        session_date,
        start_time,
        end_time,
        topic,
        created_by
      ) values (
        target_offering.id,
        target_offering.batch_id,
        p_session_date,
        p_start_time,
        p_end_time,
        nullif(btrim(p_topic), ''),
        ctx.profile_id
      )
      returning * into target_session;
    end if;
  end if;

  insert into public.attendance_records (
    session_id,
    student_id,
    batch_id,
    status,
    recorded_by
  )
  select
    target_session.id,
    (item ->> 'student_id')::uuid,
    target_offering.batch_id,
    (item ->> 'status')::public.attendance_status,
    ctx.profile_id
  from jsonb_array_elements(p_records) item
  on conflict (session_id, student_id) do update
    set status = excluded.status,
        recorded_by = ctx.profile_id,
        updated_at = now();

  select count(*)::integer
    into total_count
    from public.attendance_records ar
   where ar.session_id = target_session.id;

  return jsonb_build_object(
    'session_id', target_session.id,
    'offering_id', target_session.offering_id,
    'batch_id', target_session.batch_id,
    'session_date', target_session.session_date,
    'start_time', target_session.start_time,
    'end_time', target_session.end_time,
    'saved_count', input_count,
    'record_count', total_count
  );
end;
$$;

revoke all on function public.create_batch_course(text, text, numeric, smallint, text, text)
  from public;
revoke all on function public.create_batch_course(text, text, numeric, smallint, text, text)
  from anon;
grant execute on function public.create_batch_course(text, text, numeric, smallint, text, text)
  to authenticated;

revoke all on function public.update_batch_course(uuid, text, text, numeric, smallint, text, text)
  from public;
revoke all on function public.update_batch_course(uuid, text, text, numeric, smallint, text, text)
  from anon;
grant execute on function public.update_batch_course(uuid, text, text, numeric, smallint, text, text)
  to authenticated;

revoke all on function public.delete_batch_course(uuid) from public;
revoke all on function public.delete_batch_course(uuid) from anon;
grant execute on function public.delete_batch_course(uuid) to authenticated;

revoke all on function public.get_batch_attendance_roster(uuid) from public;
revoke all on function public.get_batch_attendance_roster(uuid) from anon;
grant execute on function public.get_batch_attendance_roster(uuid) to authenticated;

revoke all on function public.cr_save_attendance(uuid, date, jsonb, uuid, time, time, text)
  from public;
revoke all on function public.cr_save_attendance(uuid, date, jsonb, uuid, time, time, text)
  from anon;
grant execute on function public.cr_save_attendance(uuid, date, jsonb, uuid, time, time, text)
  to authenticated;

comment on function public.create_batch_course(text, text, numeric, smallint, text, text) is
  'Active CR only: atomically creates/reuses a department course and creates/restores an offering for the caller batch.';
comment on function public.update_batch_course(uuid, text, text, numeric, smallint, text, text) is
  'Active CR only: updates an offering in the caller batch and safely updates unshared catalogue metadata.';
comment on function public.delete_batch_course(uuid) is
  'Active CR only: soft-deletes an offering from the caller batch without deleting another batch course or its content.';
comment on function public.get_batch_attendance_roster(uuid) is
  'Active CR only: returns the minimum identity fields needed to take attendance for one active offering in the caller batch.';
comment on function public.cr_save_attendance(uuid, date, jsonb, uuid, time, time, text) is
  'Active CR only: atomically creates/updates a class session and upserts validated attendance for active members of that batch.';
