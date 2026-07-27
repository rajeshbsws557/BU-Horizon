-- BU Horizon — Registration now captures the student's Academic System
-- (semester / yearly) and their current Semester/Year directly on the profile.
-- These student-selected values become the source of truth for how the app
-- labels and scopes the student's terms, instead of deriving them from the
-- program/batch.

-- ---------------------------------------------------------------------------
-- 1. New profile columns.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists academic_system public.academic_system,
  add column if not exists current_term smallint
    check (current_term is null or current_term >= 1);

comment on column public.profiles.academic_system is
  'Student-selected academic system (semester/yearly) captured at registration. Source of truth for term labelling.';
comment on column public.profiles.current_term is
  'Student-selected current semester/year captured at registration.';

-- ---------------------------------------------------------------------------
-- 2. Persist the two new sign-up metadata fields on profile creation.
-- ---------------------------------------------------------------------------
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id, email, full_name, roll, student_id, phone,
    faculty_id, department_id, batch_id,
    academic_system, current_term
  )
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.raw_user_meta_data->>'roll',
    new.raw_user_meta_data->>'student_id',
    new.raw_user_meta_data->>'phone',
    nullif(new.raw_user_meta_data->>'faculty_id','')::uuid,
    nullif(new.raw_user_meta_data->>'department_id','')::uuid,
    nullif(new.raw_user_meta_data->>'batch_id','')::uuid,
    nullif(new.raw_user_meta_data->>'academic_system','')::public.academic_system,
    nullif(new.raw_user_meta_data->>'current_term','')::smallint
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
