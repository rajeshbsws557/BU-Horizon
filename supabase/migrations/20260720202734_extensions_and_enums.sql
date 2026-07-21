-- BU Horizon — 01. Extensions, schemas, and enum types
-- Foundation objects that every later migration depends on.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
-- Installed into the `extensions` schema (hosted Supabase convention; keeps
-- `public` clean). Usages qualify the type as extensions.citext.
create extension if not exists "pgcrypto" with schema extensions;  -- gen_random_uuid()
create extension if not exists "citext" with schema extensions;   -- case-insensitive email/text

-- ---------------------------------------------------------------------------
-- Schemas
-- ---------------------------------------------------------------------------
-- `private` holds SECURITY DEFINER helper functions used by RLS. It is NOT
-- exposed through the Data API, so these helpers are not callable by clients.
create schema if not exists private;

-- ---------------------------------------------------------------------------
-- Enum types
-- ---------------------------------------------------------------------------

-- Accounts / roles. A user has exactly one role at a time (poll Q21).
-- A CR is a student with extra CRUD privileges (poll Q25).
create type public.user_role as enum ('student', 'cr', 'super_admin');

create type public.profile_status as enum ('active', 'suspended', 'archived', 'deleted');

-- Program academic system, fixed per program (poll Q2, Q3).
create type public.academic_system as enum ('semester', 'yearly');

-- Batch lifecycle (poll Q27). Batches remain accessible in every state.
create type public.batch_status as enum ('active', 'graduated', 'delayed', 'suspended', 'archived');

-- Attendance. `upcoming` is a UI-only state and is intentionally not stored.
create type public.attendance_status as enum ('present', 'absent');

-- Request workflows (poll Q7 batch change, Q42 attendance corrections).
create type public.request_status as enum ('pending', 'accepted', 'rejected', 'cancelled');

-- Class schedule variants (poll Q44).
create type public.schedule_type as enum ('one_time', 'rescheduled', 'cancelled', 'online');

-- Exams (poll Q47, Q48). Covers routines and final-exam notices.
create type public.exam_type as enum ('midterm', 'final', 'quiz', 'other');

-- Notices (poll Q49, Q50, Q51). University-wide notices are super-admin only.
create type public.notice_scope as enum ('university', 'batch');
create type public.notice_state as enum ('draft', 'scheduled', 'published', 'archived');
create type public.notice_priority as enum ('low', 'normal', 'high', 'urgent');
-- Mirrors the app's NoticeCategory (academic, events, department) plus exam/general.
create type public.notice_category as enum ('general', 'academic', 'exam', 'event', 'department');

-- Resources (poll Q52).
create type public.resource_type as enum ('file', 'image', 'link');

-- Notifications (poll Q55).
create type public.notification_channel as enum ('in_app', 'push');

-- Campus services (from the app: Blood Help, Lost & Found).
create type public.blood_group as enum ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-');
create type public.blood_request_status as enum ('open', 'fulfilled', 'cancelled');
create type public.lost_found_type as enum ('lost', 'found');
create type public.lost_found_status as enum ('open', 'resolved', 'archived');
