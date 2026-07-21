-- BU Horizon — 05. Schedules and exams
-- Schedule types: one-time, rescheduled, cancelled, online (poll Q44). Stores
-- selected fields — room, floor, teacher, course (optional), meeting link when
-- online (poll Q45). Conflict detection is surfaced to the CR (poll Q46) via a
-- helper view; CRs resolve conflicts between themselves. Exams: notices and
-- routines (poll Q47), associated with courses (poll Q48).

-- ---------------------------------------------------------------------------
-- Class schedules
-- ---------------------------------------------------------------------------
create table public.class_schedules (
  id            uuid primary key default gen_random_uuid(),
  batch_id      uuid not null references public.batches (id) on delete cascade,
  offering_id   uuid references public.course_offerings (id) on delete set null, -- course optional (poll Q45)
  type          public.schedule_type not null default 'one_time',

  schedule_date date not null,
  start_time    time,
  end_time      time,

  room          text,
  building_floor text,                        -- floor of the building (poll Q45)
  teacher_name  text,                         -- teachers have no accounts (poll Q14)
  meeting_link  text,                         -- only for online classes (poll Q45)

  -- For rescheduled classes, point back to the original occurrence.
  original_schedule_id uuid references public.class_schedules (id) on delete set null,
  note          text,

  created_by    uuid references public.profiles (id) on delete set null, -- the CR
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,                  -- soft-delete (poll Q35, Q59)

  -- Meeting link only makes sense for online classes.
  constraint chk_online_link check (meeting_link is null or type = 'online')
);
create index idx_schedules_batch_date on public.class_schedules (batch_id, schedule_date);
create index idx_schedules_offering on public.class_schedules (offering_id);
-- Support fast room/time conflict lookups (poll Q46).
create index idx_schedules_room_slot on public.class_schedules (schedule_date, room)
  where deleted_at is null and type <> 'cancelled';

comment on table public.class_schedules is
  'Batch class schedule entries. Conflict detection (poll Q46) is provided via the class_schedule_conflicts view; resolution is manual between CRs.';

-- ---------------------------------------------------------------------------
-- Exams — routines and notices, associated with a course (poll Q47, Q48).
-- ---------------------------------------------------------------------------
create table public.exams (
  id           uuid primary key default gen_random_uuid(),
  batch_id     uuid not null references public.batches (id) on delete cascade,
  offering_id  uuid references public.course_offerings (id) on delete set null, -- association with course (poll Q48)
  type         public.exam_type not null default 'other',
  title        text not null,
  title_bn     text,
  description  text,
  exam_date    date,
  start_time   time,
  end_time     time,
  room         text,
  created_by   uuid references public.profiles (id) on delete set null, -- the CR
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz                    -- soft-delete (poll Q35, Q59)
);
create index idx_exams_batch on public.exams (batch_id);
create index idx_exams_offering on public.exams (offering_id);
create index idx_exams_date on public.exams (exam_date);
