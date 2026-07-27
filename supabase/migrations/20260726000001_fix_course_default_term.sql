-- BU Horizon — Fix: CR-added courses defaulted to term 1.
--
-- Bug: create_batch_course() derived the term for a new course from
-- ctx.current_term, which comes from batches.current_term. That column is
-- frequently left at its seeded default (1) and is never advanced, so every
-- course a CR added — regardless of the CR's real, student-selected term —
-- landed in the 1st semester.
--
-- Fix: prefer the CR's own profile.current_term (the source of truth added in
-- 20260725000001) when the CR does not pass an explicit term, falling back to
-- the batch term only if the profile term is missing. An explicit p_term_number
-- from the editor still wins so a CR can back-fill a previous term on purpose.

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
  cr_current_term smallint;
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

  -- The CR's own registered term is the source of truth for "the current
  -- semester", not the (often stale) batches.current_term.
  select p.current_term
    into cr_current_term
    from public.profiles p
   where p.id = (select auth.uid());

  effective_term := coalesce(p_term_number, cr_current_term, ctx.current_term);
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
