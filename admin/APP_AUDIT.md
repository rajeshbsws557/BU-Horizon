# BU Horizon application and data audit

This audit maps the Flutter application as it exists on 2026-07-21 to the
Supabase schema and the corresponding admin modules.

## Application architecture

- Flutter uses `go_router`, BLoC, GetIt/injectable, repository interfaces, and
  Supabase-backed implementations when credentials are configured.
- A UI-only mode swaps to sample repositories and bypasses auth when Supabase
  defines are intentionally blank.
- Auth supports registration, university email or student-ID login through
  `resolve_login_email`, password reset, email confirmation, and profile/session
  loading.
- Supabase Auth creates `profiles` through a database trigger. Authorization is
  sourced from `profiles`; role, batch, and department are mirrored into Auth
  app metadata.
- The Flutter UI currently contains no CR- or admin-specific management screens.

## Feature-to-data coverage

| Flutter section | Current app behavior | Supabase relations | Admin coverage |
| --- | --- | --- | --- |
| Home | Static shortcuts, profile greeting, nearest exam; next bus uses bundled Dart data | `profiles`, `exams` | Profiles/exams are managed; static tiles have no backing table |
| Registration/profile | Register, login/reset, profile read, logout | `auth.users`, `profiles`, academic reference tables | Profile search/update/status; Auth identity creation/deletion is intentionally not emulated with raw profile writes |
| Bus schedule | Read/search/filter live routes with bundled fallback | `bus_routes`, `bus_trips`; `bus_route_favorites` exists but is unused in Flutter | Full route/trip/favourite CRUD and ordering |
| Class notices | Read visible published university/batch notices | `notices`; attachment/read tables are not used by Flutter yet | Full lifecycle CRUD, bilingual fields, scope, priority, pinning, attachment metadata, receipts |
| People search | Search a limited university directory and open email | `people_directory` | Read-only directory plus full profile management |
| Attendance | Student reads only their own records and client-side totals | `class_sessions`, `attendance_records`, offerings/courses | Session/record/correction CRUD; immutable history and summary reporting |
| Exams | Read non-deleted batch exams | `exams`, offerings/courses | Full CRUD and archive/restore |
| Resources | Read non-deleted metadata and open `external_url` | `resources` | Full metadata CRUD and archive/restore |
| Alerts | Read/filter the broadcast activity feed | `alerts` | Full CRUD; per-user `notifications` is a separate module |
| Blood help | Read/create requests and send/view responses | `blood_requests`, `blood_request_responses`; donor registration is not wired in Flutter | Request, donor, and response CRUD/moderation |
| Lost and found | Read/create reports and send/view responses | `lost_found_items`, `lost_found_responses` | Item and response CRUD/moderation |
| About/settings | Static text and several coming-soon actions | None | No false CRUD surface is shown because no app-consumed database table exists |

## Public database inventory

The database contains 30 public base tables and two views.

- Academic structure: `faculties`, `departments`, `programs`, `batches`,
  `courses`, `course_offerings`.
- Accounts: `profiles`, `cr_assignments`.
- Classes and attendance: `class_sessions`, `attendance_records`,
  `attendance_history`, `attendance_correction_requests`.
- Scheduling/content: `class_schedules`, `exams`, `notices`,
  `notice_attachments`, `notice_reads`, `resources`.
- Workflows/system: `batch_change_requests`, `notifications`, `audit_logs`.
- Campus services: `bus_routes`, `bus_trips`, `bus_route_favorites`,
  `blood_requests`, `blood_donors`, `blood_request_responses`,
  `lost_found_items`, `lost_found_responses`, `alerts`.
- Views: `people_directory`, `attendance_summary`.

The database explorer obtains this list dynamically from the secured catalog
RPC, so later public relations are also visible.

Public workflow RPCs are `resolve_login_email`, `advance_batch`,
`review_batch_change_request`, and `get_schedule_conflicts`. Migration 18 adds
`admin_set_cr`, `review_attendance_correction_request`, and
`admin_schema_catalog`.

## CR authorization model

A working CR requires both `profiles.role = 'cr'` and a matching
`cr_assignments` row. Updating only one leaves an inconsistent account. The new
admin RPC therefore:

1. verifies an active super administrator;
2. locks the profile and owning batch;
3. validates promotion eligibility and own-batch assignment;
4. enforces the two-CR cap;
5. changes the role and assignment in one transaction;
6. verifies postconditions and writes an immutable audit event.

Unpromotion can clean up inactive/archived/stale CR accounts and returns the
profile to `student` only when no assignment remains.

## Security and integrity findings addressed

- Original privileged helpers did not reject suspended, archived, or
  soft-deleted admins/CRs. Migration 18 now fails closed.
- Super admins lacked complete RLS access to notifications, favourites,
  receipts, workflow rows, and response tables. Targeted policies close those
  gaps without making audit/history mutable.
- Browser-side two-write CR changes could partially succeed. They are replaced
  with a transactional security-definer RPC.
- Batch-change and attendance-correction review columns are state-machine
  fields. Migration 18 blocks raw transitions, performs review through audited
  RPCs, and applies accepted attendance corrections to the source record in the
  same transaction.
- Denormalized academic batch keys now have database validation: offerings,
  sessions, attendance, corrections, schedules, exams, and resources cannot
  reference a parent from another batch.
- The browser never receives a service-role key or database password.
- Protected layouts call `auth.getUser()`, verify the live profile, and require
  AAL2 rather than trusting user-editable metadata.

## Known product/backend gaps

- Home's next-bus card uses bundled timetable data, so database bus edits affect
  the bus screen but not that home card.
- The router exposes Alerts, Blood Help, and Lost & Found to guests, while RLS
  grants anonymous reads only for bus/reference registration data. Those guest
  routes can show empty/error states until product intent is aligned.
- Flutter does not yet use route favourites, notice attachments/receipts,
  attendance corrections, donor registration, real alarms, profile editing, or
  any CR tooling even though much of the schema exists.
- The home notification badge is static and the Alerts screen does not consume
  `notifications`.
- No Supabase Storage/R2 bucket is configured. `storage_path` and `image_path`
  are metadata; URLs work where the Flutter repository opens `external_url`.
- `profile.status = 'suspended'` is now sufficient to remove privileged
  admin/CR authority, but a full student Auth ban still requires a deliberate
  server-side Auth Admin operation.
- Existing privileged audit coverage is strongest for CR changes, batch
  advancement, batch changes, and attendance-correction reviews. Generic domain
  CRUD is not automatically written to `audit_logs` by the current schema.
- Most Flutter list repositories cap queries at 50 rows; the admin website uses
  server-side pagination instead.
- Migration 17 deliberately replaces bus routes/trips with the real timetable,
  while `supabase/seed.sql` appends demo routes after migrations during a local
  reset. A production migration-only dataset and a seeded local reset therefore
  differ until that seed strategy is consolidated.

## Intentional read-only data

`audit_logs` is trigger-protected and append-only. `attendance_history` is
trigger-generated. `people_directory` and `attendance_summary` are derived
views. Treating these as read-only is required for correctness and does not
reduce CRUD coverage of the app's source data.
