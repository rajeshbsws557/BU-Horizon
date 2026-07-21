-- BU Horizon — 03. Accounts, profiles, and CR assignments
-- Students self-register and are auto-approved (poll Q18, Q19). CR accounts are
-- created by the super admin only (poll Q18). A user has exactly one role
-- (poll Q21). Login is by university email or student ID (poll Q22); auth itself
-- is handled by Supabase Auth (auth.users) — this table is the app profile.

-- ---------------------------------------------------------------------------
-- Profiles (1:1 with auth.users)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  role           public.user_role not null default 'student',

  -- Identity information required at registration (poll Q20).
  full_name      text not null,
  roll           text,                       -- class roll
  student_id     text,                       -- from the physical ID card
  -- University email name@bu.ac.bd (poll Q20). citext = case-insensitive.
  email          extensions.citext not null,
  phone          text,

  faculty_id     uuid references public.faculties (id) on delete set null,
  department_id  uuid references public.departments (id) on delete set null,
  batch_id       uuid references public.batches (id) on delete set null,

  status         public.profile_status not null default 'active',
  avatar_url     text,
  locale         text not null default 'en' check (locale in ('en', 'bn')), -- poll Q67

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,                -- deleted users' academic records are preserved (poll Q64)

  unique (email),
  unique (student_id),
  -- Enforce the university email domain when the value is an email (poll Q20).
  constraint chk_email_domain check (email ~* '^[^@\s]+@bu\.ac\.bd$')
);
create index idx_profiles_department on public.profiles (department_id);
create index idx_profiles_batch on public.profiles (batch_id);
create index idx_profiles_role on public.profiles (role);
create index idx_profiles_status on public.profiles (status);

comment on table public.profiles is
  'App-level user profile, 1:1 with auth.users. Role stored here AND mirrored into auth JWT app_metadata by a trigger so RLS can read it without recursion.';

-- ---------------------------------------------------------------------------
-- CR assignments
-- A batch has one CR, max two (poll Q31). Appointed/removed by super admin only
-- (poll Q32). No start/end dates or history (poll Q33) — a row simply exists
-- while the assignment is active and is deleted when revoked.
-- ---------------------------------------------------------------------------
create table public.cr_assignments (
  id          uuid primary key default gen_random_uuid(),
  batch_id    uuid not null references public.batches (id) on delete cascade,
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  assigned_by uuid references public.profiles (id) on delete set null, -- super admin
  created_at  timestamptz not null default now(),
  unique (batch_id, profile_id)
);
create index idx_cr_assignments_batch on public.cr_assignments (batch_id);
create index idx_cr_assignments_profile on public.cr_assignments (profile_id);

comment on table public.cr_assignments is
  'Active CR appointments. Max 2 per batch (poll Q31), enforced by a trigger. Managed by super admin only (poll Q32).';
