-- BU Horizon — 20. Club Information, Members, Activities, and Notices
--
-- Creates tables, RLS policies, indexes, triggers, and seed data for the
-- Barishal University Intelligent Systems & Security Forum (BU ISSF) club.

create table if not exists public.club_info (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'BU ISSF (Barishal University Intelligent Systems & Security Forum)',
  tagline text not null default 'Innovating, Securing, and Building the Future of Intelligent Systems at Barishal University',
  description text not null default 'BU ISSF is the premier student forum of the University of Barishal dedicated to Artificial Intelligence, Machine Learning, Cybersecurity, Cloud Computing, and Software Engineering. Founded to foster collaborative research and practical engineering skills, we organize hackathons, technical bootcamps, and cybersecurity drills.',
  founding_year text not null default '2023',
  contact_email text not null default 'issf@bu.ac.bd',
  logo_url text,
  hero_image_url text,
  total_members integer not null default 150,
  active_projects integer not null default 18,
  total_events integer not null default 32,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.club_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  designation text not null,
  role_type text not null default 'executive',
  department text not null default 'Computer Science and Engineering',
  batch text not null default '10th Batch',
  avatar_url text,
  email text,
  phone text,
  sort_order integer not null default 10,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.club_activities (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  category text not null default 'Workshop',
  activity_date text not null default 'Recent Semester',
  location text not null default 'BU Campus / Online',
  image_url text,
  is_featured boolean not null default true,
  sort_order integer not null default 10,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.club_notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text not null,
  body text not null,
  category text not null default 'general',
  priority text not null default 'normal',
  is_pinned boolean not null default false,
  published_at timestamptz not null default now(),
  attachment_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes
create index if not exists idx_club_members_sort on public.club_members (sort_order, is_active);
create index if not exists idx_club_activities_sort on public.club_activities (sort_order, is_featured);
create index if not exists idx_club_notices_published on public.club_notices (is_pinned desc, published_at desc);

-- Triggers for updated_at
create trigger set_updated_at_club_info
  before update on public.club_info
  for each row execute function private.set_updated_at();

create trigger set_updated_at_club_members
  before update on public.club_members
  for each row execute function private.set_updated_at();

create trigger set_updated_at_club_activities
  before update on public.club_activities
  for each row execute function private.set_updated_at();

create trigger set_updated_at_club_notices
  before update on public.club_notices
  for each row execute function private.set_updated_at();

-- Enable Row Level Security
alter table public.club_info enable row level security;
alter table public.club_members enable row level security;
alter table public.club_activities enable row level security;
alter table public.club_notices enable row level security;

-- Public read access (anon & authenticated) so guests and students can browse club details
create policy club_info_anon_read on public.club_info for select to anon using (true);
create policy club_info_auth_read on public.club_info for select to authenticated using (true);
create policy club_info_admin on public.club_info for all to authenticated using (private.is_super_admin()) with check (private.is_super_admin());

create policy club_members_anon_read on public.club_members for select to anon using (true);
create policy club_members_auth_read on public.club_members for select to authenticated using (true);
create policy club_members_admin on public.club_members for all to authenticated using (private.is_super_admin()) with check (private.is_super_admin());

create policy club_activities_anon_read on public.club_activities for select to anon using (true);
create policy club_activities_auth_read on public.club_activities for select to authenticated using (true);
create policy club_activities_admin on public.club_activities for all to authenticated using (private.is_super_admin()) with check (private.is_super_admin());

create policy club_notices_anon_read on public.club_notices for select to anon using (true);
create policy club_notices_auth_read on public.club_notices for select to authenticated using (true);
create policy club_notices_admin on public.club_notices for all to authenticated using (private.is_super_admin()) with check (private.is_super_admin());

-- Seed initial data if tables are empty
do $$
begin
  if not exists (select 1 from public.club_info) then
    insert into public.club_info (name, tagline, description, founding_year, contact_email, total_members, active_projects, total_events)
    values (
      'BU ISSF (Barishal University Intelligent Systems & Security Forum)',
      'Innovating, Securing, and Building the Future of Intelligent Systems at Barishal University',
      'BU ISSF is the premier student forum of the University of Barishal dedicated to Artificial Intelligence, Machine Learning, Cybersecurity, Cloud Computing, and Software Engineering. Founded to foster collaborative research and practical engineering skills, we organize hackathons, technical bootcamps, and cybersecurity drills.',
      '2023',
      'issf@bu.ac.bd',
      150,
      18,
      32
    );
  end if;

  if not exists (select 1 from public.club_members) then
    insert into public.club_members (name, designation, role_type, department, batch, email, sort_order, is_active)
    values
      ('Md. Tanvir Ahmed', 'President', 'executive', 'Computer Science and Engineering', '9th Batch', 'tanvir.issf@bu.ac.bd', 1, true),
      ('Nusrat Jahan Ananya', 'Vice President', 'executive', 'Computer Science and Engineering', '9th Batch', 'ananya.issf@bu.ac.bd', 2, true),
      ('S. M. Shahriar Rahman', 'General Secretary', 'executive', 'Computer Science and Engineering', '10th Batch', 'shahriar.issf@bu.ac.bd', 3, true),
      ('Tahsin Kazi', 'Treasurer & Finance Lead', 'executive', 'Department of Management', '10th Batch', 'tahsin.issf@bu.ac.bd', 4, true),
      ('Abrar Fahad', 'Lead Cybersecurity Analyst', 'core', 'Computer Science and Engineering', '10th Batch', 'abrar.issf@bu.ac.bd', 5, true),
      ('Fariha Tasnim', 'AI & Machine Learning Coordinator', 'core', 'Computer Science and Engineering', '11th Batch', 'fariha.issf@bu.ac.bd', 6, true);
  end if;

  if not exists (select 1 from public.club_activities) then
    insert into public.club_activities (title, description, category, activity_date, location, is_featured, sort_order)
    values
      ('National Cybersecurity Flag Capture (CTF) Bootcamp', 'Intensive 3-day hands-on bootcamp focusing on penetration testing, network forensics, and reverse engineering. Participants competed in real-time red-team/blue-team scenarios.', 'Hackathon', '2026 Semester 1', 'Computer Lab 2, Academic Building', true, 1),
      ('Applied Deep Learning & Neural Networks Workshop', 'Comprehensive hands-on training covering PyTorch, Transformer architectures, and fine-tuning Large Language Models for academic and industrial problem solving.', 'Workshop', 'Summer 2026', 'Central Auditorium', true, 2),
      ('Open Source Contribution & Git Bootcamp', 'Introductory bootcamp designed to transition junior engineering students into active open source contributors, covering version control, pull requests, and CI/CD basics.', 'Seminar', 'Fall 2025', 'Academic Building 1, Room 302', true, 3),
      ('Ethical Hacking & Web Penetration Testing Drill', 'Weekly interactive study circle testing vulnerabilities in sandbox environments using industry-standard penetration tools and OWASP guidelines.', 'Study Group', 'Ongoing Weekly', 'Virtual & CSE Lab 3', false, 4);
  end if;

  if not exists (select 1 from public.club_notices) then
    insert into public.club_notices (title, subtitle, body, category, priority, is_pinned, published_at)
    values
      ('Call for Executive Committee Nominations 2026-2027', 'Applications are now open for leadership roles in the upcoming tenure.', 'BU ISSF invites passionate and dedicated members from all departments to submit their applications for executive and core leadership positions for the 2026-2027 tenure. Candidates must demonstrate active participation in forum activities and strong technical/leadership acumen.\n\nDeadline: August 15, 2026.', 'event', 'high', true, now() - interval '2 hours'),
      ('Upcoming AI & Cybersecurity Hackathon Registration Open', 'Form your teams of 3-4 and register for the campus-wide hackathon.', 'Registration is live for the Barishal University Tech Odyssey 2026! Compete in AI solution tracks or cybersecurity defense challenges for prize money and mentorship opportunities.\n\nVisit the forum office or check our online portal to submit your team rosters.', 'event', 'normal', true, now() - interval '2 days'),
      ('Weekly Study Circle: Introduction to Cryptography & Zero-Knowledge Proofs', 'Join us this Thursday at 4:00 PM in Lab 3.', 'Our weekly technical meetup will explore modern cryptographic foundations, elliptic curve cryptography, and practical applications of Zero-Knowledge Proofs (ZKPs) in blockchain and privacy-preserving protocols. Open to all students.', 'academic', 'normal', false, now() - interval '5 days');
  end if;
end;
$$;
