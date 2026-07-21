# BU Horizon Admin

Standalone Next.js + TypeScript administration website for the BU Horizon
Flutter app and its Supabase backend. It lives beside Flutter's generated
`web/` directory so the two build systems remain independent.

## What is included

- Live dashboard metrics and recent privileged activity.
- Student/profile management with protected account fields.
- Atomic CR promotion and unpromotion, own-batch validation, a two-CR cap, and
  audit events.
- CRUD workspaces for academic structure, attendance, schedules, exams,
  notices, resources, alerts, notifications, transport, blood help, lost and
  found, and request workflows.
- Schema-driven field types, enum inputs, foreign-key selectors, generated
  defaults, server-side row pagination/search/sort, column visibility, raw row
  inspection, CSV export, soft-delete/restore, and guarded hard delete.
- A database explorer covering every table and view in the Supabase `public`
  schema, including relations added later.
- Read-only enforcement in the UI and database for `audit_logs`,
  `attendance_history`, `people_directory`, and `attendance_summary`.
- Supabase Auth, active `super_admin` authorization, mandatory TOTP/AAL2,
  responsive navigation, and light/dark themes.

## Required database migration

Apply the migrations in `../supabase/migrations`, including:

```text
20260721000018_admin_panel_support.sql
```

Migration 18 adds the secure `admin_set_cr`,
`review_attendance_correction_request`, and `admin_schema_catalog` RPCs,
closes missing super-admin RLS policy gaps, and makes privileged role helpers
fail closed for inactive/deleted accounts. The admin website can still show
ordinary tables before that migration, but generated create/edit forms and CR
changes deliberately require it.

For a linked project:

```bash
npx supabase db push
```

Review pending migrations before pushing them to a production project. This
repository does not apply production database changes automatically.

## First super administrator

There is no public admin signup. Create and confirm a normal university account
first, then bootstrap one trusted account from the Supabase SQL editor:

```sql
update public.profiles
set role = 'super_admin', status = 'active', deleted_at = null
where email = 'trusted-admin@bu.ac.bd';
```

On first admin login, the website requires TOTP enrollment and verification.
Keep at least one separately secured recovery administrator before suspending or
archiving an admin account.

## Local setup

1. Copy `.env.example` to `.env.local`.
2. Set the project URL and browser-safe publishable key.
3. Install dependencies and start the site.

```bash
npm install
npm run dev
```

Open `http://localhost:3000`. Add that URL and the production URL to the
Supabase Auth redirect allow-list.

The browser uses only:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

Never put the database password or service-role key in a `NEXT_PUBLIC_`
variable. The current panel does not require a service-role key for CRUD or CR
management; signed-in admin JWTs and RLS remain the authorization boundary.

## Routes

| Route | Purpose |
| --- | --- |
| `/` | Dashboard, attention queues, content health, recent audit activity |
| `/students` | Profiles, directory data, and protected CR-assignment view |
| `/cr-management` | Promote/unpromote registered students atomically |
| `/academics` | Faculties, departments, programs, batches, courses, offerings |
| `/attendance` | Sessions, records, corrections, history, summary view |
| `/content` | Schedules, exams, notices, attachments, receipts, resources, alerts, notifications |
| `/campus` | Bus routes/trips/favourites, blood help, lost and found |
| `/workflows` | Batch-change and attendance-correction requests, notifications |
| `/database` | Every public table/view, structural metadata, data export |
| `/audit` | Immutable privileged activity |

Batch-change approval, attendance-correction review, and batch advancement use
transactional Supabase RPCs rather than editing workflow status fields directly.

## Data-safety conventions

- Tables with `deleted_at` archive and restore by default. Permanent delete is
  separate and warns about foreign-key/cascade risk.
- Profile creation/deletion and Auth email changes are not performed as raw
  public-table writes. A `profiles` row is not a substitute for `auth.users`.
- Profile role/email/ID fields are protected in generic forms. CR roles use the
  dedicated RPC. An admin cannot suspend their own current profile in the UI.
- Program `academic_system` is database-immutable after creation.
- Batch term/graduation changes and request review fields are database-guarded;
  use their dedicated workflow actions. Academic relationship triggers reject
  mismatched denormalized batch IDs before they can affect RLS visibility.
- File fields currently manage metadata/URLs only because no storage bucket is
  configured in this project.
- Dates are stored by Supabase and presented in the Asia/Dhaka timezone.

## Verification

```bash
npm run typecheck
npm run lint
npm run build
```

The production build is a normal Next.js server deployment. Vercel, a Node
host, or a container can be used; configure the same environment variables and
Supabase Auth redirect URLs on the target.

See `APP_AUDIT.md` for the feature/data audit and known Flutter/backend gaps.
