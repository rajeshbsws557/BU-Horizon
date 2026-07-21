-- BU Horizon - course content and resource-storage hardening
--
-- Class notices and resources are course-scoped. This migration closes the
-- remaining legacy escape hatches, protects offering identity from direct CR
-- updates, and provisions a private Supabase Storage bucket for course files.

-- ---------------------------------------------------------------------------
-- Legacy normalization and fail-fast assessment
-- ---------------------------------------------------------------------------

-- Older clients represented remotely hosted files/images as file/image rows
-- with only external_url. Preserve those links without pretending that they
-- are native Storage objects.
-- Drop the old, weaker check inside this transaction so malformed legacy rows
-- can be normalized before the stricter replacement is validated below.
alter table public.resources
  drop constraint if exists chk_resource_target;

update public.resources
   set storage_path = null
 where storage_path is not null
   and btrim(storage_path) = '';

update public.resources
   set external_url = null
 where external_url is not null
   and btrim(external_url) = '';

update public.resources
   set type = 'link'::public.resource_type,
       storage_path = null,
       updated_at = now()
 where type in ('file'::public.resource_type, 'image'::public.resource_type)
   and storage_path is null
   and external_url is not null;

-- Native files/images have one canonical target: the private Storage object.
-- If a migrated row already has that object, a stale fallback URL is dropped.
update public.resources
   set external_url = null,
       updated_at = now()
 where type in ('file'::public.resource_type, 'image'::public.resource_type)
   and storage_path is not null
   and external_url is not null;

-- A link is never a native object reference. Clearing a stale path is safe:
-- external_url was already required for link rows by chk_resource_target.
update public.resources
   set storage_path = null,
       updated_at = now()
 where type = 'link'::public.resource_type
   and storage_path is not null;

do $$
declare
  invalid_count bigint;
begin
  select count(*)
    into invalid_count
    from public.notices n
   where n.scope = 'batch'::public.notice_scope
     and n.offering_id is null;

  if invalid_count > 0 then
    raise exception using
      errcode = '23514',
      message = 'Cannot require a course for every batch notice.',
      detail = format('%s legacy batch notice row(s) have no offering_id.', invalid_count),
      hint = 'Assign each row to the correct course offering, then rerun this migration.';
  end if;

  select count(*)
    into invalid_count
    from public.resources r
   where r.offering_id is null;

  if invalid_count > 0 then
    raise exception using
      errcode = '23514',
      message = 'Cannot require a course for every resource.',
      detail = format('%s legacy resource row(s) have no offering_id.', invalid_count),
      hint = 'Assign each row to the correct course offering, then rerun this migration.';
  end if;

  select count(*)
    into invalid_count
    from public.resources r
   where (r.type = 'link'::public.resource_type and r.external_url is null)
      or (
        r.type in ('file'::public.resource_type, 'image'::public.resource_type)
        and r.storage_path is null
      );

  if invalid_count > 0 then
    raise exception using
      errcode = '23514',
      message = 'Cannot enforce strict resource targets.',
      detail = format('%s resource row(s) have neither the required URL nor Storage path.', invalid_count),
      hint = 'Give links an external_url and files/images a course-resources storage_path, then rerun this migration.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Strict course linkage and target semantics
-- ---------------------------------------------------------------------------

alter table public.notices
  drop constraint if exists chk_notice_offering_scope;
alter table public.notices
  add constraint chk_notice_offering_scope
  check (
    (
      scope = 'university'::public.notice_scope
      and batch_id is null
      and offering_id is null
    )
    or (
      scope = 'batch'::public.notice_scope
      and batch_id is not null
      and offering_id is not null
    )
  ) not valid;
alter table public.notices
  validate constraint chk_notice_offering_scope;

alter table public.resources
  alter column offering_id set not null;

alter table public.resources
  add constraint chk_resource_target
  check (
    (
      type = 'link'::public.resource_type
      and external_url is not null
      and btrim(external_url) <> ''
      and storage_path is null
    )
    or (
      type in ('file'::public.resource_type, 'image'::public.resource_type)
      and storage_path is not null
      and btrim(storage_path) <> ''
      and external_url is null
    )
  ) not valid;
alter table public.resources
  validate constraint chk_resource_target;

-- SET NULL would violate the new invariant and silently detach content from a
-- course. Administrators can still hard-delete an empty offering; offerings
-- with content must be archived or have their content deliberately removed.
alter table public.notices
  drop constraint if exists notices_offering_id_fkey;
alter table public.notices
  add constraint notices_offering_id_fkey
  foreign key (offering_id)
  references public.course_offerings (id)
  on delete restrict;

alter table public.resources
  drop constraint if exists resources_offering_id_fkey;
alter table public.resources
  add constraint resources_offering_id_fkey
  foreign key (offering_id)
  references public.course_offerings (id)
  on delete restrict;

comment on column public.notices.offering_id is
  'Required course offering for batch notices; NULL only for university notices.';
comment on column public.resources.offering_id is
  'Required course offering that scopes this resource to one batch course.';
comment on column public.resources.storage_path is
  'Native object name in the private course-resources bucket: <batch UUID>/<offering UUID>/<uploader UUID>/<filename>.';

-- ---------------------------------------------------------------------------
-- Canonical Storage path parsing and row/path integrity
-- ---------------------------------------------------------------------------

create or replace function private.course_resource_path_parts(object_name text)
returns table (
  path_batch_id uuid,
  path_offering_id uuid,
  path_uploader_id uuid
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  parts text[];
  uuid_pattern constant text :=
    '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
  if object_name is null then
    return;
  end if;

  parts := string_to_array(object_name, '/');
  if coalesce(array_length(parts, 1), 0) <> 4
     or coalesce(btrim(parts[4]), '') in ('', '.', '..')
     or parts[1] !~* uuid_pattern
     or parts[2] !~* uuid_pattern
     or parts[3] !~* uuid_pattern then
    return;
  end if;

  path_batch_id := parts[1]::uuid;
  path_offering_id := parts[2]::uuid;
  path_uploader_id := parts[3]::uuid;
  return next;
end;
$$;

revoke all on function private.course_resource_path_parts(text)
  from public, anon, authenticated;

create or replace function private.enforce_course_resource_storage_path()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  path_info record;
begin
  if new.type = 'link'::public.resource_type then
    return new;
  end if;

  select *
    into path_info
    from private.course_resource_path_parts(new.storage_path);

  if not found then
    raise exception using
      errcode = '23514',
      message = 'A stored resource needs a valid course-resources object path.',
      hint = 'Use <batch UUID>/<offering UUID>/<uploader UUID>/<filename>.';
  end if;

  if path_info.path_batch_id is distinct from new.batch_id
     or path_info.path_offering_id is distinct from new.offering_id then
    raise exception using
      errcode = '23514',
      message = 'The resource Storage path must match its batch and course offering.';
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_course_resource_storage_path()
  from public, anon, authenticated;

-- Refuse to install the trigger over malformed legacy native-object rows.
do $$
declare
  invalid_count bigint;
begin
  select count(*)
    into invalid_count
    from public.resources r
    left join lateral private.course_resource_path_parts(r.storage_path) p on true
   where r.type in ('file'::public.resource_type, 'image'::public.resource_type)
     and (
       p.path_batch_id is null
       or p.path_batch_id is distinct from r.batch_id
       or p.path_offering_id is distinct from r.offering_id
     );

  if invalid_count > 0 then
    raise exception using
      errcode = '23514',
      message = 'Cannot enforce course resource Storage paths.',
      detail = format('%s native resource row(s) have a malformed or mismatched storage_path.', invalid_count),
      hint = 'Move each object to <batch UUID>/<offering UUID>/<uploader UUID>/<filename>, update storage_path, then rerun this migration.';
  end if;
end;
$$;

drop trigger if exists trg_course_resource_storage_path on public.resources;
create trigger trg_course_resource_storage_path
  before insert or update of type, storage_path, batch_id, offering_id
  on public.resources
  for each row execute function private.enforce_course_resource_storage_path();

-- ---------------------------------------------------------------------------
-- Offering identity is RPC/admin-owned
-- ---------------------------------------------------------------------------

create or replace function private.protect_course_offering_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.course_id is distinct from old.course_id
     or new.batch_id is distinct from old.batch_id then
    -- Authenticated super admins (AAL2), service-role jobs, and direct database
    -- administrators retain maintenance access. A CR must use the protected
    -- course RPCs, none of which reparent an existing offering.
    if auth.uid() is not null and not private.is_super_admin() then
      raise exception using
        errcode = '42501',
        message = 'Course offering course_id and batch_id cannot be changed directly.',
        hint = 'Create the intended offering through the protected course workflow instead.';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.protect_course_offering_identity()
  from public, anon, authenticated;

drop trigger if exists trg_protect_course_offering_identity
  on public.course_offerings;
create trigger trg_protect_course_offering_identity
  before update of course_id, batch_id
  on public.course_offerings
  for each row execute function private.protect_course_offering_identity();

-- ---------------------------------------------------------------------------
-- Private course-resources bucket and object authorization
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('course-resources', 'course-resources', false, 26214400)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit;

create or replace function private.can_read_course_resource_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from private.course_resource_path_parts(object_name) p
      join public.resources r
        on r.storage_path = object_name
       and r.batch_id = p.path_batch_id
       and r.offering_id = p.path_offering_id
      join public.course_offerings co
        on co.id = r.offering_id
       and co.batch_id = r.batch_id
      join public.courses c on c.id = co.course_id
     where r.type in ('file'::public.resource_type, 'image'::public.resource_type)
       and r.deleted_at is null
       and co.deleted_at is null
       and c.deleted_at is null
       and private.is_active_batch_member(r.batch_id)
  );
$$;

create or replace function private.can_insert_course_resource_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from private.course_resource_path_parts(object_name) p
      join public.course_offerings co
        on co.id = p.path_offering_id
       and co.batch_id = p.path_batch_id
      join public.courses c on c.id = co.course_id
     where p.path_uploader_id = (select auth.uid())
       and co.deleted_at is null
       and c.deleted_at is null
       and private.is_cr_of_batch(p.path_batch_id)
  );
$$;

create or replace function private.can_update_course_resource_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from private.course_resource_path_parts(object_name) p
      join public.course_offerings co
        on co.id = p.path_offering_id
       and co.batch_id = p.path_batch_id
      join public.courses c on c.id = co.course_id
     where co.deleted_at is null
       and c.deleted_at is null
       and private.is_cr_of_batch(p.path_batch_id)
  );
$$;

create or replace function private.can_delete_course_resource_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from private.course_resource_path_parts(object_name) p
      join public.course_offerings co
        on co.id = p.path_offering_id
       and co.batch_id = p.path_batch_id
     where private.is_cr_of_batch(p.path_batch_id)
  );
$$;

revoke all on function private.can_read_course_resource_object(text)
  from public, anon;
revoke all on function private.can_insert_course_resource_object(text)
  from public, anon;
revoke all on function private.can_update_course_resource_object(text)
  from public, anon;
revoke all on function private.can_delete_course_resource_object(text)
  from public, anon;
grant execute on function private.can_read_course_resource_object(text)
  to authenticated;
grant execute on function private.can_insert_course_resource_object(text)
  to authenticated;
grant execute on function private.can_update_course_resource_object(text)
  to authenticated;
grant execute on function private.can_delete_course_resource_object(text)
  to authenticated;

drop policy if exists course_resources_member_select on storage.objects;
create policy course_resources_member_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'course-resources'
    and private.can_read_course_resource_object(name)
  );

-- Storage update/delete operations also require row visibility. CRs are the
-- managers for their own batch path, including orphan cleanup after metadata
-- or an offering has been archived; regular students still require the exact
-- active resources reference above.
drop policy if exists course_resources_cr_select on storage.objects;
create policy course_resources_cr_select
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'course-resources'
    and private.can_delete_course_resource_object(name)
  );

drop policy if exists course_resources_cr_insert on storage.objects;
create policy course_resources_cr_insert
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'course-resources'
    and private.can_insert_course_resource_object(name)
  );

drop policy if exists course_resources_cr_update on storage.objects;
create policy course_resources_cr_update
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'course-resources'
    and private.can_update_course_resource_object(name)
  )
  with check (
    bucket_id = 'course-resources'
    and private.can_update_course_resource_object(name)
  );

drop policy if exists course_resources_cr_delete on storage.objects;
create policy course_resources_cr_delete
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'course-resources'
    and private.can_delete_course_resource_object(name)
  );

drop policy if exists course_resources_super_admin_all on storage.objects;
create policy course_resources_super_admin_all
  on storage.objects
  for all
  to authenticated
  using (
    bucket_id = 'course-resources'
    and (select private.is_super_admin())
  )
  with check (
    bucket_id = 'course-resources'
    and (select private.is_super_admin())
  );

comment on function private.can_read_course_resource_object(text) is
  'Allows an active batch member to read only an active file/image resource row that references this exact private object.';
comment on function private.can_insert_course_resource_object(text) is
  'Allows an active batch CR to upload under their own UUID for an active offering in that batch.';
comment on function private.can_update_course_resource_object(text) is
  'Allows an active batch CR to update a valid object path for an active offering in that batch.';
comment on function private.can_delete_course_resource_object(text) is
  'Allows an active batch CR to remove a valid object path in that batch, including cleanup after offering archival.';

-- ---------------------------------------------------------------------------
-- Role changes must reach already-open clients
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1
      from pg_catalog.pg_publication
     where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
      from pg_catalog.pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'profiles'
  ) then
    execute 'alter publication supabase_realtime add table public.profiles';
  end if;
end;
$$;
