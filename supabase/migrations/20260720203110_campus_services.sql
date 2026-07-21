-- BU Horizon — 08. Campus services: bus, blood, lost & found, alerts
-- These features exist in the app but are outside the academic poll. Bus routes
-- are university-wide reference data. Blood requests and lost & found are
-- university-wide, student-authored posts. Alerts are the app's activity feed.

-- ---------------------------------------------------------------------------
-- Bus routes and trips (mirrors university_bus_schedule_data.dart)
-- ---------------------------------------------------------------------------
create table public.bus_routes (
  id           uuid primary key default gen_random_uuid(),
  category     text not null default 'Student',   -- e.g. Student / Teacher
  name         text not null,
  name_bn      text,
  description  text,
  description_bn text,
  manager_info text,
  window_label text,                               -- e.g. '7:30 AM - 10:30 PM'
  frequency    text,                               -- e.g. 'Every 20 min'
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_bus_routes_category on public.bus_routes (category);

-- A trip = a departure from a place at a time on a route.
create table public.bus_trips (
  id              uuid primary key default gen_random_uuid(),
  route_id        uuid not null references public.bus_routes (id) on delete cascade,
  departure_place text not null,
  departure_place_bn text,
  depart_time     text not null,                   -- kept as label to match source data ('8:30 AM')
  bus_name        text,
  sort_order      int not null default 0
);
create index idx_bus_trips_route on public.bus_trips (route_id);

-- Per-user favorite routes (app's toggleFavorite).
create table public.bus_route_favorites (
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  route_id    uuid not null references public.bus_routes (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (profile_id, route_id)
);

-- ---------------------------------------------------------------------------
-- Blood help — requests and donor registrations
-- ---------------------------------------------------------------------------
create table public.blood_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid references public.profiles (id) on delete set null,
  blood_group  public.blood_group not null,
  units        smallint check (units > 0),
  contact      text,
  location     text,
  note         text,
  is_urgent    boolean not null default false,
  status       public.blood_request_status not null default 'open',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_blood_requests_status on public.blood_requests (status, created_at desc);
create index idx_blood_requests_group on public.blood_requests (blood_group);

create table public.blood_donors (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles (id) on delete cascade,
  blood_group  public.blood_group not null,
  contact      text,
  last_donated date,
  available    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (profile_id)
);
create index idx_blood_donors_group on public.blood_donors (blood_group) where available;

-- ---------------------------------------------------------------------------
-- Lost & found
-- ---------------------------------------------------------------------------
create table public.lost_found_items (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid references public.profiles (id) on delete set null,
  type         public.lost_found_type not null,   -- lost / found
  title        text not null,
  description  text,
  location     text,
  image_path   text,                               -- object storage path (optional)
  status       public.lost_found_status not null default 'open',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index idx_lost_found_type_status on public.lost_found_items (type, status, created_at desc);

-- ---------------------------------------------------------------------------
-- Alerts — the app's activity feed (bus/notice/exam/event/library/lost_found).
-- These are broadcast items; per-user read state reuses `notifications` if a
-- targeted copy is needed, but the feed itself is university-wide.
-- ---------------------------------------------------------------------------
create table public.alerts (
  id          uuid primary key default gen_random_uuid(),
  type        text not null check (type in ('bus','notice','exam','event','library','lost_found')),
  title       text not null,
  subtitle    text,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now()
);
create index idx_alerts_type on public.alerts (type, created_at desc);
