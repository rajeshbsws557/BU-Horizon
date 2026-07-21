# BU Horizon — Supabase Database

This directory holds the full Postgres schema for the BU Horizon campus app,
built from the app's feature set and `university-app-database-requirements-poll.md`.
It is a set of imperative migrations you apply with the Supabase CLI.

## Layout

```
supabase/
  config.toml                    # local CLI config (auth MFA, storage, exposed schemas)
  seed.sql                       # reference data (faculty/dept/program/batch, bus routes)
  migrations/
    ...01_extensions_and_enums.sql
    ...02_academic_hierarchy.sql
    ...03_profiles_and_cr.sql
    ...04_courses_attendance.sql
    ...05_schedules_exams.sql
    ...06_notices_resources.sql
    ...07_requests_notifications_audit.sql
    ...08_campus_services.sql
    ...09_functions_triggers.sql
    ...10_views.sql
    ...11_rls_enable_and_reference.sql
    ...12_rls_academic_content.sql
    ...13_rls_notices_services.sql
```

## Applying it

```bash
supabase init          # only if this project isn't linked yet
supabase start         # local stack (needs Docker)
supabase db reset      # runs all migrations in order, then seed.sql
```

To push to a hosted project: `supabase link --project-ref <ref>` then `supabase db push`.

The project is linked to its hosted Supabase database. Before deployment, use
`supabase db push --dry-run`, run the pgTAP suite in `supabase/tests`, and run
`supabase db lint`; then apply pending migrations with `supabase db push`.

## Design overview

### Academic hierarchy (structured, poll Q1–Q10)
`faculties → departments → programs → batches`. One BSc program per department;
`programs.academic_system` (semester/yearly) is fixed at creation and locked by
a trigger (poll Q3). A **batch** is admission year + session (e.g. `2025-26`),
has no sections (poll Q5), and its `current_term` is advanced by the CR through
`advance_batch()` — there is no academic calendar (poll Q9, Q40).

### Accounts and roles (poll Q18–Q25)
`profiles` is 1:1 with `auth.users`. A user has exactly one `role`
(`student` / `cr` / `super_admin`). Students self-register and are auto-approved
via the `handle_new_user` trigger; CR and admin accounts are provisioned by the
super admin. The university email domain `@bu.ac.bd` is enforced by a CHECK.
`review_batch_change_request()` handles the dropped-out/not-promoted flow
(poll Q7): student requests from their batch, the destination-batch CR accepts,
and the student's `batch_id` moves.

### Isolation (poll Q28, Q29) — enforced by RLS
- Academic content (offerings, sessions, attendance, schedules, exams,
  resources, batch notices) is visible **only to the owning batch's members and
  that batch's CR**, plus super admin.
- Reference data (faculties, departments, programs, batches, courses, bus
  routes) is readable university-wide so registration and directories work.
- **University-wide public notices** (super-admin authored) are readable by all
  (poll Q28).
- The **people directory** is a deliberate university-wide lookup exposing only
  name, email, and department (see note below).

### CR privileges (poll Q31–Q36)
CRs get full CRUD on their batch's schedules, attendance, notices, resources,
and exams, and accept batch-member change requests. Max 2 CRs per batch
(trigger-enforced). Deletes are **soft** (`deleted_at`), matching poll Q35/Q59.

### Attendance (poll Q37–Q43)
Recorded per class session, present/absent only, by the CR. Every status change
is written to `attendance_history` by a trigger (poll Q41). Students file
`attendance_correction_requests` (poll Q42). `attendance_summary` view provides
percentage and course-wise figures for reports (poll Q43).

### Audit and immutability (poll Q58)
`audit_logs` is insert-only: no client write policy, and a trigger blocks
UPDATE/DELETE. Privileged actions (CR assignment via app, batch advance, batch
change acceptance) write entries.

### Campus services (from the app, outside the poll)
`bus_routes` / `bus_trips` / `bus_route_favorites`, `blood_requests` /
`blood_donors`, `lost_found_items`, and `alerts`. These are university-wide;
posts are author-owned.

## Security notes

- **`private` schema, not exposed.** RLS helper functions
  (`current_role`, `current_batch`, `is_cr_of_batch`, `is_super_admin`, …) live
  in `private`, which `config.toml` keeps out of the Data API. They are
  `SECURITY DEFINER` only to read the caller's *own* profile row without
  recursive RLS, and never take arbitrary ids.
- **Role in `app_metadata`, not `user_metadata`.** A trigger mirrors
  `profiles.role`/`batch_id`/`department_id` into `auth.users.raw_app_meta_data`
  (non-user-editable) so JWT-based checks are safe. The database source of truth
  is `profiles`; RLS reads it via the `private` helpers.
- **`people_directory` is SECURITY DEFINER by design.** Base `profiles` RLS
  hides other users, so an invoker view would return nothing. The view exposes
  only name/email/department for active users and is granted to `authenticated`
  only (revoked from `anon`).
- **RPCs are locked down.** `review_batch_change_request`, `advance_batch`, and
  `get_schedule_conflicts` `REVOKE ... FROM public` then `GRANT ... TO
  authenticated`, and each re-checks authorization (CR-of-batch or super admin)
  in its body.
- Two-factor is required for all users (poll Q61) — enabled in `config.toml`
  under `[auth.mfa]`; enforcement of *enrollment* is an app/edge concern.

## Decisions made during design

These came up while reconciling the app with the poll; confirmed with you:

1. **Scope = everything in the app** — academic core plus bus, blood, lost &
   found, and alerts.
2. **People Search = university-wide directory** (name/department/email), while
   all academic content stays batch/department-isolated.
3. **Structured reference tables** for the Faculty→Department→Program→Batch
   hierarchy (not free-text) — required for reliable RLS isolation.
4. **Course files use private Supabase Storage.** Native files/images are stored
   in the `course-resources` bucket under batch/course/uploader paths. Students
   can read only objects referenced by active resources for their batch; CRs
   manage objects only for their own batch. Web links use `external_url`.

## Still open / provider-dependent

- **Push notifications** (poll Q55): `notifications` rows carry a `channel`;
  fan-out to FCM/APNs is an edge-function/client concern, not modeled here.
- **Exports & backups** (poll Q63, Q65): CSV/Excel/PDF exports and manual
  backups are operational tasks (CLI / dashboard), not schema objects.
