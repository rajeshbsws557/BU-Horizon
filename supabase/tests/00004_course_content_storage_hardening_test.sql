begin;

create extension if not exists pgtap with schema extensions;

create or replace function pg_temp.caught_sqlstate(statement text)
returns text
language plpgsql
as $$
begin
  execute statement;
  return null;
exception
  when others then
    return sqlstate;
end;
$$;

select extensions.plan(21);

-- Isolated academic hierarchy.
insert into public.faculties (id, name, code)
values ('10000000-0000-4000-8000-000000000001', 'Hardening Test Faculty', 'HTF');

insert into public.departments (id, faculty_id, name, code)
values (
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'Hardening Test Department',
  'HTD'
);

insert into public.programs (
  id, department_id, name, code, academic_system, total_terms
)
values (
  '30000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000001',
  'Hardening Test Program',
  'HTP',
  'semester',
  8
);

insert into public.batches (
  id, program_id, admission_year, session, name, current_term
)
values
  (
    '40000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    2098,
    '2098-99',
    'Hardening Batch A',
    1
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000001',
    2097,
    '2097-98',
    'Hardening Batch B',
    1
  );

insert into public.courses (id, department_id, code, title, term_number)
values
  (
    '50000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'HT-101',
    'Hardening One',
    1
  ),
  (
    '50000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000001',
    'HT-102',
    'Hardening Two',
    1
  );

insert into public.course_offerings (
  id, course_id, batch_id, term_number, teacher_name
)
values
  (
    '60000000-0000-4000-8000-000000000001',
    '50000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001',
    1,
    'Original Teacher'
  ),
  (
    '60000000-0000-4000-8000-000000000002',
    '50000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000002',
    1,
    'Other Teacher'
  );

-- Auth rows invoke handle_new_user(), producing ordinary student profiles.
insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '70000000-0000-4000-8000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'hardening-cr@bu.ac.bd',
    '',
    now(),
    '{}'::jsonb,
    jsonb_build_object(
      'full_name', 'Hardening CR',
      'student_id', 'HT-CR',
      'faculty_id', '10000000-0000-4000-8000-000000000001',
      'department_id', '20000000-0000-4000-8000-000000000001',
      'batch_id', '40000000-0000-4000-8000-000000000001'
    ),
    now(),
    now()
  ),
  (
    '70000000-0000-4000-8000-000000000002',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'hardening-student@bu.ac.bd',
    '',
    now(),
    '{}'::jsonb,
    jsonb_build_object(
      'full_name', 'Hardening Student',
      'student_id', 'HT-STUDENT',
      'faculty_id', '10000000-0000-4000-8000-000000000001',
      'department_id', '20000000-0000-4000-8000-000000000001',
      'batch_id', '40000000-0000-4000-8000-000000000001'
    ),
    now(),
    now()
  ),
  (
    '70000000-0000-4000-8000-000000000003',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'hardening-outsider@bu.ac.bd',
    '',
    now(),
    '{}'::jsonb,
    jsonb_build_object(
      'full_name', 'Hardening Outsider',
      'student_id', 'HT-OUTSIDER',
      'faculty_id', '10000000-0000-4000-8000-000000000001',
      'department_id', '20000000-0000-4000-8000-000000000001',
      'batch_id', '40000000-0000-4000-8000-000000000002'
    ),
    now(),
    now()
  );

update public.profiles
   set role = 'cr'::public.user_role
 where id = '70000000-0000-4000-8000-000000000001';

insert into public.cr_assignments (batch_id, profile_id)
values (
  '40000000-0000-4000-8000-000000000001',
  '70000000-0000-4000-8000-000000000001'
);

select extensions.ok(
  exists (
    select 1
      from storage.buckets
     where id = 'course-resources'
       and public = false
       and file_size_limit = 26214400
  ),
  'course-resources is a private 25 MiB bucket'
);

select extensions.ok(
  exists (
    select 1
      from pg_catalog.pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'profiles'
  ),
  'profiles is in the Supabase Realtime publication'
);

select extensions.is(
  pg_temp.caught_sqlstate($sql$
    insert into public.notices (
      id, scope, batch_id, title, created_by
    ) values (
      '90000000-0000-4000-8000-000000000001',
      'batch',
      '40000000-0000-4000-8000-000000000001',
      'Missing course',
      '70000000-0000-4000-8000-000000000001'
    )
  $sql$),
  '23514',
  'a batch notice without an offering is rejected'
);

select extensions.is(
  pg_temp.caught_sqlstate($sql$
    insert into public.resources (
      id, batch_id, type, title, external_url, created_by
    ) values (
      '80000000-0000-4000-8000-000000000001',
      '40000000-0000-4000-8000-000000000001',
      'link',
      'Missing course',
      'https://example.test/resource',
      '70000000-0000-4000-8000-000000000001'
    )
  $sql$),
  '23502',
  'a resource without an offering is rejected'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);

select extensions.is(
  pg_temp.caught_sqlstate($sql$
    update public.course_offerings
       set course_id = '50000000-0000-4000-8000-000000000002'
     where id = '60000000-0000-4000-8000-000000000001'
  $sql$),
  '42501',
  'a CR cannot directly change an offering course_id'
);

select extensions.lives_ok(
  $sql$
    update public.course_offerings
       set teacher_name = 'Updated Teacher'
     where id = '60000000-0000-4000-8000-000000000001'
  $sql$,
  'a CR may update mutable offering metadata'
);

select extensions.is(
  (
    select teacher_name
      from public.course_offerings
     where id = '60000000-0000-4000-8000-000000000001'
  ),
  'Updated Teacher',
  'the allowed teacher update persisted'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',
  true
);

select extensions.is(
  (select count(*) from public.course_offerings),
  1::bigint,
  'a student sees only offerings in their own batch'
);

select extensions.lives_ok(
  $sql$
    update public.course_offerings
       set teacher_name = 'Student Tampering'
     where id = '60000000-0000-4000-8000-000000000001'
  $sql$,
  'an unauthorized offering update safely affects no rows'
);

select extensions.is(
  (
    select teacher_name
      from public.course_offerings
     where id = '60000000-0000-4000-8000-000000000001'
  ),
  'Updated Teacher',
  'a regular student cannot alter offering metadata'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);
select extensions.lives_ok(
  $sql$
    insert into storage.objects (bucket_id, name)
    values (
      'course-resources',
      '40000000-0000-4000-8000-000000000001/60000000-0000-4000-8000-000000000001/70000000-0000-4000-8000-000000000001/lecture-01.pdf'
    )
  $sql$,
  'an active CR can upload to their own active course path'
);

select extensions.is(
  pg_temp.caught_sqlstate($sql$
    insert into storage.objects (bucket_id, name)
    values (
      'course-resources',
      '40000000-0000-4000-8000-000000000002/60000000-0000-4000-8000-000000000002/70000000-0000-4000-8000-000000000001/other.pdf'
    )
  $sql$),
  '42501',
  'a CR cannot upload to another batch course path'
);

select extensions.is(
  pg_temp.caught_sqlstate($sql$
    insert into public.resources (
      id, batch_id, offering_id, type, title, storage_path
    ) values (
      '80000000-0000-4000-8000-000000000002',
      '40000000-0000-4000-8000-000000000001',
      '60000000-0000-4000-8000-000000000001',
      'file',
      'Malformed path',
      'wrong/path.pdf'
    )
  $sql$),
  '23514',
  'resource metadata rejects a malformed object path'
);

select extensions.lives_ok(
  $sql$
    insert into public.resources (
      id,
      batch_id,
      offering_id,
      type,
      title,
      storage_path,
      file_name
    ) values (
      '80000000-0000-4000-8000-000000000003',
      '40000000-0000-4000-8000-000000000001',
      '60000000-0000-4000-8000-000000000001',
      'file',
      'Lecture 01',
      '40000000-0000-4000-8000-000000000001/60000000-0000-4000-8000-000000000001/70000000-0000-4000-8000-000000000001/lecture-01.pdf',
      'lecture-01.pdf'
    )
  $sql$,
  'a CR can create matching native resource metadata'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',
  true
);

select extensions.is(
  (
    select count(*)
      from storage.objects
     where bucket_id = 'course-resources'
  ),
  1::bigint,
  'a same-batch student can read an object referenced by an active resource'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000003', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000003","role":"authenticated","aal":"aal1"}',
  true
);

select extensions.is(
  (
    select count(*)
      from storage.objects
     where bucket_id = 'course-resources'
  ),
  0::bigint,
  'a student in another batch cannot read the object'
);

select extensions.is(
  pg_temp.caught_sqlstate($sql$
    insert into storage.objects (bucket_id, name)
    values (
      'course-resources',
      '40000000-0000-4000-8000-000000000002/60000000-0000-4000-8000-000000000002/70000000-0000-4000-8000-000000000003/student.pdf'
    )
  $sql$),
  '42501',
  'a regular student cannot upload course resources'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);
select extensions.lives_ok(
  $sql$
    update public.resources
       set deleted_at = now()
     where id = '80000000-0000-4000-8000-000000000003'
  $sql$,
  'the CR can soft-delete resource metadata'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000002', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000002","role":"authenticated","aal":"aal1"}',
  true
);

select extensions.is(
  (
    select count(*)
      from storage.objects
     where bucket_id = 'course-resources'
  ),
  0::bigint,
  'soft-deleting metadata immediately revokes student object access'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-4000-8000-000000000001', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"70000000-0000-4000-8000-000000000001","role":"authenticated","aal":"aal1"}',
  true
);

-- Supabase Storage sets this transaction-local guard after it has removed the
-- backing object; direct SQL deletion is otherwise (correctly) refused.
select set_config('storage.allow_delete_query', 'true', true);

select extensions.lives_ok(
  $sql$
    delete from storage.objects
     where bucket_id = 'course-resources'
       and name = '40000000-0000-4000-8000-000000000001/60000000-0000-4000-8000-000000000001/70000000-0000-4000-8000-000000000001/lecture-01.pdf'
  $sql$,
  'the CR can delete an object after its metadata is archived'
);

reset role;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{}', true);

select extensions.is(
  (
    select count(*)
      from storage.objects
     where bucket_id = 'course-resources'
       and name = '40000000-0000-4000-8000-000000000001/60000000-0000-4000-8000-000000000001/70000000-0000-4000-8000-000000000001/lecture-01.pdf'
  ),
  0::bigint,
  'the archived resource object was removed'
);

select * from extensions.finish();

rollback;
