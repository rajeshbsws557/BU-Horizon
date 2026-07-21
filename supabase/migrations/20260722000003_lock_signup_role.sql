-- Public sign-up always creates a student. Super-admin promotion remains an
-- explicit database-administration operation and cannot be requested through
-- Auth user metadata.

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    role,
    email,
    full_name,
    roll,
    student_id,
    phone,
    faculty_id,
    department_id,
    batch_id
  )
  values (
    new.id,
    'student'::public.user_role,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.raw_user_meta_data->>'roll',
    new.raw_user_meta_data->>'student_id',
    new.raw_user_meta_data->>'phone',
    nullif(new.raw_user_meta_data->>'faculty_id', '')::uuid,
    nullif(new.raw_user_meta_data->>'department_id', '')::uuid,
    nullif(new.raw_user_meta_data->>'batch_id', '')::uuid
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function private.handle_new_user() is
  'Creates an active student profile from public Auth sign-up metadata; privileged roles require explicit database administration.';

