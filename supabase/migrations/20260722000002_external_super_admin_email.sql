-- Permit a trusted super administrator to use a non-university email address
-- while preserving the @bu.ac.bd restriction for students and CRs.

alter table public.profiles
  drop constraint if exists chk_email_domain;

alter table public.profiles
  add constraint chk_email_domain check (
    email ~* '^[^@\s]+@bu\.ac\.bd$'
    or (
      role = 'super_admin'::public.user_role
      and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    )
  );

-- Auth Admin can set raw_app_meta_data, whereas public sign-up cannot. This
-- enables a one-step, trigger-safe bootstrap of the first super administrator.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  initial_role public.user_role := case
    when new.raw_app_meta_data->>'role' = 'super_admin'
      then 'super_admin'::public.user_role
    else 'student'::public.user_role
  end;
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
    initial_role,
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
  'Creates an active student profile for public sign-up, or a super-admin profile when that role is supplied through protected Auth app metadata.';
