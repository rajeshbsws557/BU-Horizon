-- BU Horizon — 02. Academic hierarchy: Faculty → Department → Program → Batch
-- One university (poll Q70). One department offers one BSc program (poll Q1),
-- but the schema keeps program as its own table so a department could hold more
-- later without a migration. Courses/sessions/batches hang off this tree, and
-- RLS isolation (poll Q28, Q29) is enforced through department_id / batch_id.

-- ---------------------------------------------------------------------------
-- Faculties
-- ---------------------------------------------------------------------------
create table public.faculties (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  name_bn     text,                         -- Bangla name (poll Q67 bilingual)
  code        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (name),
  unique (code)
);

-- ---------------------------------------------------------------------------
-- Departments
-- ---------------------------------------------------------------------------
create table public.departments (
  id          uuid primary key default gen_random_uuid(),
  faculty_id  uuid not null references public.faculties (id) on delete restrict,
  name        text not null,
  name_bn     text,
  code        text not null,               -- e.g. 'CSE'
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (code)
);
create index idx_departments_faculty on public.departments (faculty_id);

-- ---------------------------------------------------------------------------
-- Programs (one BSc per department in practice; poll Q1)
-- Academic system is fixed at creation and cannot switch (poll Q2, Q3),
-- enforced by a trigger in the functions migration.
-- ---------------------------------------------------------------------------
create table public.programs (
  id              uuid primary key default gen_random_uuid(),
  department_id   uuid not null references public.departments (id) on delete restrict,
  name            text not null,           -- e.g. 'BSc in Computer Science & Engineering'
  name_bn         text,
  code            text not null,
  academic_system public.academic_system not null,
  -- Number of terms in the program (8 semesters or 4 years, etc.). Used to know
  -- when a batch graduates on its final advance (poll Q39, Q40).
  total_terms     smallint not null check (total_terms > 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (code)
);
create index idx_programs_department on public.programs (department_id);

-- ---------------------------------------------------------------------------
-- Batches
-- A batch = admission year + academic session, e.g. 2025-26 (poll Q4).
-- No sections/groups (poll Q5). current_term is advanced by the CR (poll Q40);
-- there is no academic calendar (poll Q9).
-- ---------------------------------------------------------------------------
create table public.batches (
  id             uuid primary key default gen_random_uuid(),
  program_id     uuid not null references public.programs (id) on delete restrict,
  admission_year smallint not null check (admission_year between 2000 and 2100),
  -- Academic session string, validated to formats like '2025-26' (poll Q4, Q20).
  session        text not null check (session ~ '^\d{4}-\d{2}$'),
  name           text,                     -- optional display label
  current_term   smallint not null default 1 check (current_term >= 1),
  status         public.batch_status not null default 'active',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- One batch per program per session (no parallel batches in same term; poll Q8).
  unique (program_id, session)
);
create index idx_batches_program on public.batches (program_id);
create index idx_batches_status on public.batches (status);

comment on column public.batches.current_term is
  'Current semester or year number, advanced by the batch CR (poll Q40). No academic calendar exists (poll Q9).';
