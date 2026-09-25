-- BU Horizon — advance_batch() now also bumps profiles.current_term
-- for every student in the batch, so the student-level column (which the
-- Flutter app treats as the source-of-truth display value) stays in sync
-- with the batch-level progression.

create or replace function public.advance_batch(target_batch uuid)
returns public.batches
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := (select auth.uid());
  batch_row public.batches;
  max_terms smallint;
  old_term smallint;
  old_status public.batch_status;
begin
  if not (
    private.is_cr_of_batch(target_batch)
    or private.is_super_admin()
  ) then
    raise exception using
      errcode = '42501',
      message = 'Only the batch CR or an active AAL2 super admin can advance the batch.';
  end if;

  select b.*
    into batch_row
    from public.batches b
   where b.id = target_batch
   for update;

  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'Batch was not found.';
  end if;

  select p.total_terms
    into max_terms
    from public.programs p
   where p.id = batch_row.program_id;

  if batch_row.status = 'graduated'::public.batch_status then
    raise exception using
      errcode = '23514',
      message = 'The batch has already graduated.';
  end if;

  old_term := batch_row.current_term;
  old_status := batch_row.status;

  perform pg_catalog.set_config('app.advance_batch', 'on', true);

  if batch_row.current_term >= max_terms then
    update public.batches
       set status = 'graduated'::public.batch_status,
           updated_at = now()
     where id = target_batch
     returning * into batch_row;
  else
    update public.batches
       set current_term = current_term + 1,
           updated_at = now()
     where id = target_batch
     returning * into batch_row;

    -- Keep every student's profile-level current_term in sync so the
    -- Flutter app (which prefers profiles.current_term for display)
    -- immediately reflects the new semester after a refresh.
    update public.profiles
       set current_term = batch_row.current_term
     where batch_id = target_batch;
  end if;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data
  )
  values (
    actor_id,
    'batch.advanced',
    'batch',
    target_batch,
    jsonb_build_object(
      'current_term', old_term,
      'status', old_status::text
    ),
    jsonb_build_object(
      'current_term', batch_row.current_term,
      'status', batch_row.status::text
    )
  );

  return batch_row;
end;
$$;

revoke all on function public.advance_batch(uuid) from public, anon;
grant execute on function public.advance_batch(uuid) to authenticated;
