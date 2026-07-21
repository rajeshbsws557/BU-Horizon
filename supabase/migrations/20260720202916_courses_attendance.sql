-- BU Horizon — 04. Courses and attendance
-- Courses and codes are stored (poll Q11), belong to one department (poll Q12),
-- and are not elective/repeat/improvement/retake (poll Q13). Teachers have no
-- accounts (poll Q14), so a course offering stores the teacher as plain text.
-- Attendance is recorded per course per class (poll Q37) by the CR (poll Q39),
-- editable anytime with audit history (poll Q41), with student correction
-- requests (poll Q42).

-- ---------------------------------------------------------------------------
-- Courses
-- ---------------------------------------------------------------------------
create table public.courses (
  id            uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments (id) on delete restrict,
  code          text not null,             -- e.g. 'CSE-2101'
  title         text not null,
  title_bn      text,
  credit_hours  numeric(3,1) check (credit_hours >= 0),
  term_number   smallint check (term_number >= 1), -- semester/year this course sits in
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  -- Course codes unique within a department; a course belongs to one dept (poll Q12).
  unique (department_id, code)
);
create index idx_courses_department on public.courses (department_id);

-- ---------------------------------------------------------------------------
-- Course offerings — a course taught to a specific batch in a specific term.
-- One teacher per offering, stored as text (poll Q14, Q16). Attendance,
-- schedules, resources and exams all reference an offering.
-- ---------------------------------------------------------------------------
create table public.course_offerings (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references public.courses (id) on delete restrict,
  batch_id     uuid not null references public.batches (id) on delete cascade,
  term_number  smallint not null check (term_number >= 1),
  teacher_name text,                        -- teachers have no accounts (poll Q14)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  unique (course_id, batch_id, term_number)
);
create index idx_offerings_batch on public.course_offerings (batch_id);
create index idx_offerings_course on public.course_offerings (course_id);

-- ---------------------------------------------------------------------------
-- Class sessions — one physical/online class meeting of an offering.
-- Attendance is per individual class (poll Q37).
-- ---------------------------------------------------------------------------
create table public.class_sessions (
  id          uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.course_offerings (id) on delete cascade,
  batch_id    uuid not null references public.batches (id) on delete cascade, -- denormalized for RLS
  session_date date not null,
  start_time  time,
  end_time    time,
  topic       text,
  created_by  uuid references public.profiles (id) on delete set null, -- the CR
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  unique (offering_id, session_date, start_time)
);
create index idx_class_sessions_offering on public.class_sessions (offering_id);
create index idx_class_sessions_batch_date on public.class_sessions (batch_id, session_date);

-- ---------------------------------------------------------------------------
-- Attendance records — one row per student per class session.
-- Statuses: present / absent only (poll Q38).
-- ---------------------------------------------------------------------------
create table public.attendance_records (
  id          uuid primary key default gen_random_uuid(),
  session_id  uuid not null references public.class_sessions (id) on delete cascade,
  student_id  uuid not null references public.profiles (id) on delete restrict, -- preserve records (poll Q64)
  batch_id    uuid not null references public.batches (id) on delete cascade,   -- denormalized for RLS
  status      public.attendance_status not null,
  recorded_by uuid references public.profiles (id) on delete set null,          -- the CR (poll Q39)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (session_id, student_id)
);
create index idx_attendance_student on public.attendance_records (student_id);
create index idx_attendance_batch on public.attendance_records (batch_id);
create index idx_attendance_session on public.attendance_records (session_id);

-- ---------------------------------------------------------------------------
-- Attendance change history — audit trail for edits (poll Q41).
-- Immutable append-only log; written by a trigger on attendance_records.
-- ---------------------------------------------------------------------------
create table public.attendance_history (
  id          uuid primary key default gen_random_uuid(),
  record_id   uuid not null references public.attendance_records (id) on delete cascade,
  old_status  public.attendance_status,
  new_status  public.attendance_status,
  changed_by  uuid references public.profiles (id) on delete set null,
  changed_at  timestamptz not null default now()
);
create index idx_attendance_history_record on public.attendance_history (record_id);

-- ---------------------------------------------------------------------------
-- Attendance correction requests — students can request fixes (poll Q42).
-- ---------------------------------------------------------------------------
create table public.attendance_correction_requests (
  id             uuid primary key default gen_random_uuid(),
  record_id      uuid references public.attendance_records (id) on delete cascade,
  session_id     uuid not null references public.class_sessions (id) on delete cascade,
  student_id     uuid not null references public.profiles (id) on delete cascade,
  batch_id       uuid not null references public.batches (id) on delete cascade,
  requested_status public.attendance_status not null,
  reason         text,
  status         public.request_status not null default 'pending',
  reviewed_by    uuid references public.profiles (id) on delete set null, -- the CR
  reviewed_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index idx_attendance_corrections_batch on public.attendance_correction_requests (batch_id);
create index idx_attendance_corrections_student on public.attendance_correction_requests (student_id);
create index idx_attendance_corrections_status on public.attendance_correction_requests (status);
