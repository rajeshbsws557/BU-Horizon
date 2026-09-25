# BU Horizon

**Smart Campus Companion** for the University of Barishal — a full-stack mobile + web platform that gives students, Class Representatives (CRs), and administrators a single place to manage academic life, campus services, and university-wide communications.

| Component | Stack |
|-----------|-------|
| **Mobile App** | Flutter 3.10+ · Dart 3.8+ · BLoC / Cubit · GoRouter · injectable + get_it |
| **Admin Panel** | Next.js 16 · React 19 · TypeScript · TailwindCSS 4 · TanStack Query |
| **Backend** | Supabase (Postgres 17 · Auth · Storage · Row-Level Security · Edge Functions) |

---

## Features

### Mobile (Flutter)
- **Authentication** — university-email sign-up/login, password recovery, mandatory TOTP 2FA, CR-based account approval workflow
- **Home Dashboard** — customisable card grid with quick access to all modules
- **Class Schedules & Exams** — CR-managed timetables and exam dates per batch/course
- **Attendance** — per-session recording by CRs, correction requests, summary reports, CSV/PDF export
- **Notices & Resources** — batch-scoped announcements with file attachments, course materials
- **Bus Schedule** — live-highlighted trips, route maps (Leaflet), alarm reminders, favourites
- **Blood Help** — donor registry and active request board
- **Lost & Found** — campus-wide item postings
- **Emergency Alerts** — university-wide priority messages
- **People Directory** — cross-department search (name, email, department only)
- **Clubs & Activities** — university club info and event listings
- **Notifications** — in-app notification centre with channel-based organisation
- **Theme System** — light/dark mode with multiple colour palette variants

### Admin Panel (Next.js)
- **Dashboard** — live metrics, attention queues, content health, recent audit events
- **Student Management** — profiles, CR promotion/unpromotion, protected fields
- **Full CRUD** — academic hierarchy, attendance, schedules, exams, notices, resources, alerts, transport, blood help, lost & found, workflows
- **Database Explorer** — every public table and view with pagination, search, sort, CSV export
- **Immutable Audit Log** — insert-only, trigger-protected audit trail
- **Auth & Security** — Supabase Auth with mandatory TOTP/AAL2, `super_admin` role enforcement

---

## Repository Layout

```
bu_horizon/
├── lib/                     # Flutter app source (screens, BLoC, models, services)
│   ├── bloc/                # BLoC cubits and event/state classes
│   ├── config/              # App links and constants
│   ├── data/                # Local data, sample data, bus schedule data
│   ├── di/                  # Dependency injection (injectable)
│   ├── models/              # Freezed data models
│   ├── navigation/          # GoRouter configuration
│   ├── repositories/        # Repository interfaces
│   ├── screens/             # All app screens
│   ├── services/            # Background services (alarms, notifications, attendance export)
│   ├── supabase/            # Supabase client, auth, repositories
│   ├── theme/               # App theme definitions and palettes
│   └── widgets/             # Reusable UI components
├── admin/                   # Next.js admin panel (standalone)
│   ├── src/                 # App source (components, lib, routes)
│   └── .env.example         # Environment variable template
├── supabase/                # Database schema and config
│   ├── config.toml          # Supabase CLI local config
│   ├── migrations/          # 33 incremental SQL migrations (full schema + RLS)
│   ├── seed.sql             # Reference data (faculties, departments, bus routes)
│   └── tests/               # pgTAP database tests
├── assets/                  # App assets (logo, images)
├── android/                 # Android platform layer
├── ios/                     # iOS platform layer
├── web/                     # Flutter web platform layer
└── test/                    # Flutter widget and unit tests
```

---

## Getting Started (Your Own Backend)

> **These instructions guide you through setting up BU Horizon with your own Supabase project from scratch.** No credentials from the original project are included in this repository.

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.10.0 | [flutter.dev/get-started](https://docs.flutter.dev/get-started/install) |
| Dart SDK | ≥ 3.8.0 | Included with Flutter |
| Node.js | ≥ 18 | [nodejs.org](https://nodejs.org/) |
| Supabase CLI | Latest | `npm i -g supabase` |
| Docker | Latest | [docker.com](https://www.docker.com/) (required for local Supabase) |
| Git | Latest | [git-scm.com](https://git-scm.com/) |

### 1. Clone the Repository

```bash
git clone https://github.com/rajeshbsws557/BU-Horizon.git
cd BU-Horizon
```

### 2. Set Up the Supabase Backend

You have two options: **hosted** (Supabase cloud) or **local** (Docker).

#### Option A — Hosted Supabase (Recommended)

1. Create a free project at [supabase.com](https://supabase.com/dashboard).
2. Note your **Project Reference ID**, **Project URL**, and **Publishable Key** from **Project Settings → API**.
3. Link and deploy the schema:

```bash
cd supabase
supabase link --project-ref <your-project-ref>
supabase db push          # applies all 33 migrations in order
```

4. Seed the reference data (faculties, departments, programs, batches, bus routes):

```bash
# The seed file runs automatically with `supabase db reset` (local only).
# For hosted projects, paste seed.sql contents into the SQL Editor.
```

#### Option B — Local Supabase (Docker)

```bash
cd supabase
supabase start             # spins up Postgres, Auth, Storage, Studio locally
supabase db reset          # runs all migrations + seed.sql
```

The local Studio is available at `http://localhost:54323`.

### 3. Configure the Flutter App

Create a `dart_defines.json` file in the project root (**this file is .gitignored**):

```json
{
  "SUPABASE_URL": "https://<your-project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-publishable-key>"
}
```

Then run:

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

**Alternatively**, pass values directly:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

**UI-only mode** (no backend, sample data):

```bash
flutter run --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=
```

### 4. Configure the Admin Panel

```bash
cd admin
cp .env.example .env.local
```

Edit `admin/.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://<your-project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<your-publishable-key>
NEXT_PUBLIC_SITE_URL=http://localhost:3000

# Only needed for Auth Admin operations (e.g., user deletion):
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
```

> ⚠️ **Never** prefix `SUPABASE_SERVICE_ROLE_KEY` with `NEXT_PUBLIC_`. It must stay server-only.

```bash
npm install
npm run dev
```

Open `http://localhost:3000`. Add this URL to your Supabase Auth **redirect allow-list**.

### 5. Bootstrap the First Super Admin

There is no public admin signup. After creating a normal university account, promote it via the Supabase SQL Editor:

```sql
UPDATE public.profiles
SET role = 'super_admin', status = 'active', deleted_at = NULL
WHERE email = 'your-admin@your-university.edu';
```

On first admin login, the panel enforces TOTP enrollment.

---

## Architecture & Security Model

### Row-Level Security (RLS) — The Primary Security Layer

All data access is enforced at the **database level** through 33 RLS policies. The client-side publishable key provides **no privileged access** — it is architecturally equivalent to a public API endpoint URL.

```
Client (Flutter/Next.js)
  │  publishable key (public, no privileges)
  ▼
Supabase Auth → JWT with role/batch/dept claims
  │
  ▼
Postgres RLS Policies → enforce row-level access per user
```

### Key Security Design Decisions

| Layer | Mechanism |
|-------|-----------|
| **Schema isolation** | RLS helpers live in the `private` schema, excluded from the Data API via `config.toml` |
| **Role propagation** | `profiles.role` is mirrored to `auth.users.raw_app_metadata` (non-user-editable) via trigger |
| **Batch isolation** | Academic content (offerings, attendance, schedules, exams, resources, notices) is visible only to batch members + their CR + super admin |
| **CR constraints** | Max 2 CRs per batch (trigger-enforced); CRs manage only their own batch |
| **Audit immutability** | `audit_logs` is insert-only; a trigger blocks UPDATE/DELETE from all roles |
| **Soft deletes** | Tables with `deleted_at` archive rather than destroy; permanent delete is separate |
| **MFA enforcement** | TOTP 2FA is mandatory for all users (configured in `config.toml`, enforced at app level) |
| **Email domain check** | `profiles.email` has a CHECK constraint for the university domain |
| **Signup role lock** | New signups are always assigned `student` role; escalation requires admin SQL |

### What the Publishable Key Can and Cannot Do

| ✅ Allowed (by RLS design) | ❌ Blocked |
|---|---|
| Read own profile | Read other users' private data |
| Read reference data (faculties, departments, programs) | Modify reference data |
| Read own batch's academic content (after auth) | Access other batches' content |
| Unauthenticated: nothing beyond signup/login | Direct database writes without JWT |

---

## Security Testing Guide

If you want to perform security testing against your own deployment:

### 1. RLS Policy Verification

Connect to your database and verify every table has RLS enabled:

```sql
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

All tables should show `rowsecurity = true`.

### 2. Test Cross-Batch Isolation

```sql
-- As a student in batch A, try to read batch B's data:
-- (Set the JWT to a student in batch A, then query batch B's offerings)
SELECT * FROM course_offerings WHERE batch_id = '<batch-B-id>';
-- Should return 0 rows
```

### 3. Test Role Escalation Prevention

```sql
-- Try to update your own role (should be blocked):
UPDATE profiles SET role = 'super_admin' WHERE id = auth.uid();
-- Should fail: role field is protected by RLS policy
```

### 4. Test Audit Log Immutability

```sql
-- Try to delete or update audit logs (should fail):
DELETE FROM audit_logs WHERE id = '<any-id>';
UPDATE audit_logs SET action = 'tampered' WHERE id = '<any-id>';
-- Both should be blocked by the immutability trigger
```

### 5. Test Private Schema Isolation

```sql
-- From the REST API or client, try to call private functions:
-- e.g., POST to /rest/v1/rpc/current_role
-- Should return 404 (private schema not exposed via Data API)
```

### 6. Automated RLS Testing

The project includes pgTAP tests in `supabase/tests/`:

```bash
supabase test db
```

### 7. Penetration Testing Checklist

| Test | Expected Result |
|------|-----------------|
| Access Data API without JWT | Only `anon`-role policies apply (minimal read access) |
| Forge JWT with elevated role | Rejected — role is in `app_metadata`, not user-editable |
| Access `/rest/v1/rpc/private.*` | 404 — `private` schema not in API schemas |
| IDOR on batch content | 0 rows — RLS checks `batch_id` against JWT claims |
| Modify `profiles.role` via API | Denied — protected column in RLS write policies |
| Delete audit log entries | Denied — immutability trigger blocks all mutations |
| Sign up with non-university email | Denied — CHECK constraint on email domain |
| Bypass MFA | Blocked — admin panel enforces AAL2 at middleware level |

---

## Running Tests

### Flutter

```bash
flutter test                          # all widget and unit tests
flutter test test/session_controller_test.dart   # specific test
flutter analyze                       # static analysis
```

### Admin Panel

```bash
cd admin
npm run typecheck                     # TypeScript type checking
npm run lint                          # ESLint
npm run build                         # production build verification
```

### Database

```bash
cd supabase
supabase test db                      # pgTAP tests
supabase db lint                      # schema linting
supabase db push --dry-run            # preview pending migrations
```

---

## Code Generation

After modifying Freezed models or injectable modules:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Deployment

### Flutter App

```bash
# Android APK
flutter build apk --dart-define-from-file=dart_defines.json

# Android App Bundle (Play Store)
flutter build appbundle --dart-define-from-file=dart_defines.json

# iOS
flutter build ios --dart-define-from-file=dart_defines.json
```

### Admin Panel

The admin panel is a standard Next.js deployment. Set the same environment variables on your host:

```bash
cd admin
npm run build
npm start
```

Compatible with Vercel, any Node.js host, or Docker containers. Configure the Supabase Auth **redirect allow-list** with your production URL.

---

## Environment Variables Reference

### Flutter App (`dart_defines.json`)

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Yes | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Publishable (anon) key from Project Settings → API |

### Admin Panel (`admin/.env.local`)

| Variable | Required | Description |
|----------|----------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | Yes | Your Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Yes | Publishable key (safe for browser) |
| `NEXT_PUBLIC_SITE_URL` | Yes | Canonical site URL for auth redirects |
| `SUPABASE_SERVICE_ROLE_KEY` | Optional | Server-only key for Auth Admin operations |

> 🔒 **Security Note:** The `SUPABASE_SERVICE_ROLE_KEY` bypasses all RLS. Only use it in server-side code. Never expose it to the client. Never prefix it with `NEXT_PUBLIC_`.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

This project is developed for the University of Barishal. All rights reserved.

---

<p align="center">
  Built with Flutter & Supabase for the University of Barishal
</p>
