-- BU Horizon — 07. Batch-change requests, notifications, and audit log
-- Dropped-out / not-promoted students request a batch move to their CURRENT CR;
-- the DESTINATION batch's CR accepts, and the student's batch changes (poll Q7,
-- Q34 "manage batch members — accepting only"). Notifications: in-app + push
-- (poll Q55), triggered by CR changes and public notices (poll Q56), with
-- read/ack (poll Q57). Audit: immutable logs for privileged changes (poll Q58).

-- ---------------------------------------------------------------------------
-- Batch-change requests (poll Q7)
-- Flow: student submits → current-batch CR forwards/sees → target-batch CR
-- accepts → student.batch_id updated (handled by trigger/RPC in migration 09).
-- ---------------------------------------------------------------------------
create table public.batch_change_requests (
  id                uuid primary key default gen_random_uuid(),
  student_id        uuid not null references public.profiles (id) on delete cascade,
  from_batch_id     uuid not null references public.batches (id) on delete cascade,
  to_batch_id       uuid not null references public.batches (id) on delete cascade,
  reason            text,                     -- e.g. dropped out / not promoted
  status            public.request_status not null default 'pending',
  -- The target batch CR who acts on the request (poll Q34).
  reviewed_by       uuid references public.profiles (id) on delete set null,
  reviewed_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint chk_batch_change_distinct check (from_batch_id <> to_batch_id)
);
create index idx_batch_change_student on public.batch_change_requests (student_id);
create index idx_batch_change_to_batch on public.batch_change_requests (to_batch_id);
create index idx_batch_change_status on public.batch_change_requests (status);

-- ---------------------------------------------------------------------------
-- Notifications (poll Q55, Q56, Q57)
-- One row per recipient. `channel` records intended delivery; push fan-out is a
-- client/edge concern. Read/ack captured inline.
-- ---------------------------------------------------------------------------
create table public.notifications (
  id            uuid primary key default gen_random_uuid(),
  recipient_id  uuid not null references public.profiles (id) on delete cascade,
  channel       public.notification_channel not null default 'in_app',
  title         text not null,
  body          text,
  -- Loose reference to the entity that triggered it (notice/schedule/exam/...).
  entity_type   text,
  entity_id     uuid,
  is_read       boolean not null default false,
  read_at       timestamptz,
  created_at    timestamptz not null default now()
);
create index idx_notifications_recipient on public.notifications (recipient_id, is_read);
create index idx_notifications_created on public.notifications (created_at desc);

-- ---------------------------------------------------------------------------
-- Audit log — immutable record of privileged changes (poll Q58).
-- Append-only: no UPDATE/DELETE policies are granted (see RLS migration), and a
-- trigger blocks mutation at the table level as defense in depth.
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id          bigint generated always as identity primary key,
  actor_id    uuid references public.profiles (id) on delete set null,
  action      text not null,                  -- e.g. 'cr.assigned', 'batch.advanced'
  entity_type text not null,
  entity_id   uuid,
  old_data    jsonb,
  new_data    jsonb,
  metadata    jsonb,
  created_at  timestamptz not null default now()
);
create index idx_audit_entity on public.audit_logs (entity_type, entity_id);
create index idx_audit_actor on public.audit_logs (actor_id);
create index idx_audit_created on public.audit_logs (created_at desc);

comment on table public.audit_logs is
  'Immutable audit trail for privileged changes (poll Q58). Insert-only; mutation blocked by trigger.';
