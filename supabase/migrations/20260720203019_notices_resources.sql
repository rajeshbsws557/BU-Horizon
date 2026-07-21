-- BU Horizon — 06. Notices and resources
-- Notices target the whole university (super admin only) or a batch (poll Q49).
-- States: draft, scheduled, published, archived (poll Q50). Features:
-- attachments, expiration, priority, pinning, read confirmation (poll Q51).
-- Resources: files, images, external links (poll Q52); stored in cloud/object
-- storage decided later (poll Q53) — we keep path/URL metadata only. No versions,
-- upload date-time only (poll Q54).

-- ---------------------------------------------------------------------------
-- Notices
-- ---------------------------------------------------------------------------
create table public.notices (
  id            uuid primary key default gen_random_uuid(),
  scope         public.notice_scope not null,
  -- Required when scope = 'batch'; null for university-wide (super admin) notices.
  batch_id      uuid references public.batches (id) on delete cascade,
  category      public.notice_category not null default 'general',

  title         text not null,
  title_bn      text,
  body          text,
  body_bn       text,

  state         public.notice_state not null default 'draft',
  priority      public.notice_priority not null default 'normal',
  is_pinned     boolean not null default false,                 -- pinning (poll Q51)

  publish_at    timestamptz,                                    -- for scheduled state
  published_at  timestamptz,
  expires_at    timestamptz,                                    -- expiration (poll Q51)

  requires_read_confirmation boolean not null default false,    -- read confirmation (poll Q51)

  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz,                                    -- soft-delete (poll Q59)

  -- A batch notice must name a batch; a university notice must not.
  constraint chk_notice_scope check (
    (scope = 'batch' and batch_id is not null) or
    (scope = 'university' and batch_id is null)
  )
);
create index idx_notices_batch on public.notices (batch_id);
create index idx_notices_scope_state on public.notices (scope, state);
create index idx_notices_pinned on public.notices (is_pinned) where is_pinned;

-- ---------------------------------------------------------------------------
-- Notice attachments — metadata only; files live in object storage (poll Q53).
-- ---------------------------------------------------------------------------
create table public.notice_attachments (
  id          uuid primary key default gen_random_uuid(),
  notice_id   uuid not null references public.notices (id) on delete cascade,
  file_name   text not null,
  storage_path text,                          -- bucket path (provider decided later)
  external_url text,                          -- when hosted externally
  mime_type   text,
  size_bytes  bigint,
  created_at  timestamptz not null default now()  -- upload date-time (poll Q54)
);
create index idx_notice_attachments_notice on public.notice_attachments (notice_id);

-- ---------------------------------------------------------------------------
-- Notice read receipts — who read / acknowledged (poll Q51, Q57).
-- ---------------------------------------------------------------------------
create table public.notice_reads (
  id          uuid primary key default gen_random_uuid(),
  notice_id   uuid not null references public.notices (id) on delete cascade,
  profile_id  uuid not null references public.profiles (id) on delete cascade,
  read_at     timestamptz not null default now(),
  acknowledged boolean not null default false,
  unique (notice_id, profile_id)
);
create index idx_notice_reads_profile on public.notice_reads (profile_id);

-- ---------------------------------------------------------------------------
-- Resources — class materials. Types: file, image, link (poll Q52).
-- No versioning; date-time upload history only (poll Q54).
-- ---------------------------------------------------------------------------
create table public.resources (
  id           uuid primary key default gen_random_uuid(),
  batch_id     uuid not null references public.batches (id) on delete cascade,
  offering_id  uuid references public.course_offerings (id) on delete set null,
  type         public.resource_type not null,
  title        text not null,
  description  text,

  storage_path text,                          -- for file/image (object storage, poll Q53)
  external_url text,                          -- for link type
  file_name    text,
  mime_type    text,
  size_bytes   bigint,

  created_by   uuid references public.profiles (id) on delete set null, -- the CR
  created_at   timestamptz not null default now(),                       -- upload date-time (poll Q54)
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,                    -- soft-delete (poll Q35, Q59)

  -- Link resources carry a URL; file/image resources carry a storage path.
  constraint chk_resource_target check (
    (type = 'link' and external_url is not null) or
    (type in ('file', 'image') and (storage_path is not null or external_url is not null))
  )
);
create index idx_resources_batch on public.resources (batch_id);
create index idx_resources_offering on public.resources (offering_id);
