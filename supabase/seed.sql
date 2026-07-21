-- BU Horizon — seed data (reference tables only)
-- Runs on `supabase db reset`. Safe to re-run: guarded with ON CONFLICT.
-- Contains no user accounts — students self-register (poll Q18/Q19) and the
-- super admin / CRs are provisioned out of band.

-- ---------------------------------------------------------------------------
-- Faculty → Department → Program → Batch
-- Real University of Barishal academic structure: 7 faculties, 25 departments
-- (source: university_of_barishal_data.md). One undergraduate honours program
-- per department (poll Q1), all 4-year / 8-semester. CSE keeps the fixed UUIDs
-- (1111/2222/3333/4444…0001) that the demo academic content references.
-- ---------------------------------------------------------------------------
insert into public.faculties (id, name, name_bn, code) values
  ('11111111-0000-0000-0000-000000000001', 'Faculty of Engineering', 'প্রকৌশল অনুষদ', 'FOE'),
  ('11111111-0000-0000-0000-000000000002', 'Faculty of Arts and Humanities', 'কলা ও মানবিক অনুষদ', 'FAH'),
  ('11111111-0000-0000-0000-000000000003', 'Faculty of Bio-Sciences', 'জীব বিজ্ঞান অনুষদ', 'FBS'),
  ('11111111-0000-0000-0000-000000000004', 'Faculty of Business Studies', 'ব্যবসায় শিক্ষা অনুষদ', 'FBUS'),
  ('11111111-0000-0000-0000-000000000005', 'Faculty of Law', 'আইন অনুষদ', 'FOL'),
  ('11111111-0000-0000-0000-000000000006', 'Faculty of Science', 'বিজ্ঞান অনুষদ', 'FOS'),
  ('11111111-0000-0000-0000-000000000007', 'Faculty of Social Sciences', 'সামাজিক বিজ্ঞান অনুষদ', 'FSS')
on conflict (code) do nothing;

insert into public.departments (id, faculty_id, name, name_bn, code) values
  -- Faculty of Engineering
  ('22222222-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Computer Science and Engineering', 'কম্পিউটার সায়েন্স ও ইঞ্জিনিয়ারিং', 'CSE'),
  -- Faculty of Arts and Humanities
  ('22222222-0000-0000-0000-000000000003', '11111111-0000-0000-0000-000000000002', 'Bangla', 'বাংলা', 'BAN'),
  ('22222222-0000-0000-0000-000000000004', '11111111-0000-0000-0000-000000000002', 'English', 'ইংরেজি', 'ENG'),
  ('22222222-0000-0000-0000-000000000005', '11111111-0000-0000-0000-000000000002', 'History', 'ইতিহাস', 'HIST'),
  ('22222222-0000-0000-0000-000000000006', '11111111-0000-0000-0000-000000000002', 'Philosophy', 'দর্শন', 'PHIL'),
  -- Faculty of Bio-Sciences
  ('22222222-0000-0000-0000-000000000007', '11111111-0000-0000-0000-000000000003', 'Biochemistry and Biotechnology', 'বায়োকেমিস্ট্রি অ্যান্ড বায়োটেকনোলজি', 'BCB'),
  ('22222222-0000-0000-0000-000000000008', '11111111-0000-0000-0000-000000000003', 'Botany', 'উদ্ভিদবিজ্ঞান', 'BOT'),
  ('22222222-0000-0000-0000-000000000009', '11111111-0000-0000-0000-000000000003', 'Coastal Studies and Disaster Management', 'উপকূলীয় অধ্যয়ন ও দুর্যোগ ব্যবস্থাপনা', 'CSDM'),
  ('22222222-0000-0000-0000-000000000010', '11111111-0000-0000-0000-000000000003', 'Soil and Environmental Sciences', 'মৃত্তিকা ও পরিবেশ বিজ্ঞান', 'SES'),
  -- Faculty of Business Studies
  ('22222222-0000-0000-0000-000000000011', '11111111-0000-0000-0000-000000000004', 'Accounting and Information Systems', 'হিসাববিজ্ঞান ও তথ্য পদ্ধতি', 'AIS'),
  ('22222222-0000-0000-0000-000000000012', '11111111-0000-0000-0000-000000000004', 'Finance and Banking', 'ফিন্যান্স ও ব্যাংকিং', 'FB'),
  ('22222222-0000-0000-0000-000000000013', '11111111-0000-0000-0000-000000000004', 'Management Studies', 'ব্যবস্থাপনা শিক্ষা', 'MGT'),
  ('22222222-0000-0000-0000-000000000014', '11111111-0000-0000-0000-000000000004', 'Marketing', 'মার্কেটিং', 'MKT'),
  -- Faculty of Law
  ('22222222-0000-0000-0000-000000000015', '11111111-0000-0000-0000-000000000005', 'Law', 'আইন', 'LAW'),
  -- Faculty of Science
  ('22222222-0000-0000-0000-000000000016', '11111111-0000-0000-0000-000000000006', 'Chemistry', 'রসায়ন', 'CHEM'),
  ('22222222-0000-0000-0000-000000000017', '11111111-0000-0000-0000-000000000006', 'Geology and Mining', 'ভূতত্ত্ব ও খনিবিদ্যা', 'GEO'),
  ('22222222-0000-0000-0000-000000000018', '11111111-0000-0000-0000-000000000006', 'Mathematics', 'গণিত', 'MATH'),
  ('22222222-0000-0000-0000-000000000019', '11111111-0000-0000-0000-000000000006', 'Physics', 'পদার্থবিজ্ঞান', 'PHY'),
  ('22222222-0000-0000-0000-000000000020', '11111111-0000-0000-0000-000000000006', 'Statistics', 'পরিসংখ্যান', 'STAT'),
  -- Faculty of Social Sciences
  ('22222222-0000-0000-0000-000000000021', '11111111-0000-0000-0000-000000000007', 'Economics', 'অর্থনীতি', 'ECON'),
  ('22222222-0000-0000-0000-000000000022', '11111111-0000-0000-0000-000000000007', 'Mass Communication and Journalism', 'গণযোগাযোগ ও সাংবাদিকতা', 'MCJ'),
  ('22222222-0000-0000-0000-000000000023', '11111111-0000-0000-0000-000000000007', 'Political Science', 'রাষ্ট্রবিজ্ঞান', 'POLS'),
  ('22222222-0000-0000-0000-000000000024', '11111111-0000-0000-0000-000000000007', 'Public Administration', 'লোকপ্রশাসন', 'PAD'),
  ('22222222-0000-0000-0000-000000000025', '11111111-0000-0000-0000-000000000007', 'Social Work', 'সমাজকর্ম', 'SW'),
  ('22222222-0000-0000-0000-000000000026', '11111111-0000-0000-0000-000000000007', 'Sociology', 'সমাজবিজ্ঞান', 'SOC')
on conflict (code) do nothing;

-- One undergraduate honours program per department (poll Q1), 8-semester.
-- Degree title by faculty: BA (Arts), BSc (Bio-Sciences/Science/Engineering),
-- BBA (Business), LLB (Law), BSS (Social Sciences). Program UUID's last segment
-- matches its department's.
insert into public.programs (id, department_id, name, name_bn, code, academic_system, total_terms) values
  ('33333333-0000-0000-0000-000000000001', '22222222-0000-0000-0000-000000000001', 'BSc in Computer Science and Engineering', 'বিএসসি ইন কম্পিউটার সায়েন্স ও ইঞ্জিনিয়ারিং', 'BSC-CSE', 'semester', 8),
  ('33333333-0000-0000-0000-000000000003', '22222222-0000-0000-0000-000000000003', 'BA (Honours) in Bangla', 'বিএ (সম্মান) — বাংলা', 'BA-BAN', 'semester', 8),
  ('33333333-0000-0000-0000-000000000004', '22222222-0000-0000-0000-000000000004', 'BA (Honours) in English', 'বিএ (সম্মান) — ইংরেজি', 'BA-ENG', 'semester', 8),
  ('33333333-0000-0000-0000-000000000005', '22222222-0000-0000-0000-000000000005', 'BA (Honours) in History', 'বিএ (সম্মান) — ইতিহাস', 'BA-HIST', 'semester', 8),
  ('33333333-0000-0000-0000-000000000006', '22222222-0000-0000-0000-000000000006', 'BA (Honours) in Philosophy', 'বিএ (সম্মান) — দর্শন', 'BA-PHIL', 'semester', 8),
  ('33333333-0000-0000-0000-000000000007', '22222222-0000-0000-0000-000000000007', 'BSc (Honours) in Biochemistry and Biotechnology', 'বিএসসি (সম্মান) — বায়োকেমিস্ট্রি অ্যান্ড বায়োটেকনোলজি', 'BSC-BCB', 'semester', 8),
  ('33333333-0000-0000-0000-000000000008', '22222222-0000-0000-0000-000000000008', 'BSc (Honours) in Botany', 'বিএসসি (সম্মান) — উদ্ভিদবিজ্ঞান', 'BSC-BOT', 'semester', 8),
  ('33333333-0000-0000-0000-000000000009', '22222222-0000-0000-0000-000000000009', 'BSc (Honours) in Coastal Studies and Disaster Management', 'বিএসসি (সম্মান) — উপকূলীয় অধ্যয়ন ও দুর্যোগ ব্যবস্থাপনা', 'BSC-CSDM', 'semester', 8),
  ('33333333-0000-0000-0000-000000000010', '22222222-0000-0000-0000-000000000010', 'BSc (Honours) in Soil and Environmental Sciences', 'বিএসসি (সম্মান) — মৃত্তিকা ও পরিবেশ বিজ্ঞান', 'BSC-SES', 'semester', 8),
  ('33333333-0000-0000-0000-000000000011', '22222222-0000-0000-0000-000000000011', 'BBA in Accounting and Information Systems', 'বিবিএ — হিসাববিজ্ঞান ও তথ্য পদ্ধতি', 'BBA-AIS', 'semester', 8),
  ('33333333-0000-0000-0000-000000000012', '22222222-0000-0000-0000-000000000012', 'BBA in Finance and Banking', 'বিবিএ — ফিন্যান্স ও ব্যাংকিং', 'BBA-FB', 'semester', 8),
  ('33333333-0000-0000-0000-000000000013', '22222222-0000-0000-0000-000000000013', 'BBA in Management Studies', 'বিবিএ — ব্যবস্থাপনা শিক্ষা', 'BBA-MGT', 'semester', 8),
  ('33333333-0000-0000-0000-000000000014', '22222222-0000-0000-0000-000000000014', 'BBA in Marketing', 'বিবিএ — মার্কেটিং', 'BBA-MKT', 'semester', 8),
  ('33333333-0000-0000-0000-000000000015', '22222222-0000-0000-0000-000000000015', 'LLB (Honours) in Law', 'এলএলবি (সম্মান) — আইন', 'LLB-LAW', 'semester', 8),
  ('33333333-0000-0000-0000-000000000016', '22222222-0000-0000-0000-000000000016', 'BSc (Honours) in Chemistry', 'বিএসসি (সম্মান) — রসায়ন', 'BSC-CHEM', 'semester', 8),
  ('33333333-0000-0000-0000-000000000017', '22222222-0000-0000-0000-000000000017', 'BSc (Honours) in Geology and Mining', 'বিএসসি (সম্মান) — ভূতত্ত্ব ও খনিবিদ্যা', 'BSC-GEO', 'semester', 8),
  ('33333333-0000-0000-0000-000000000018', '22222222-0000-0000-0000-000000000018', 'BSc (Honours) in Mathematics', 'বিএসসি (সম্মান) — গণিত', 'BSC-MATH', 'semester', 8),
  ('33333333-0000-0000-0000-000000000019', '22222222-0000-0000-0000-000000000019', 'BSc (Honours) in Physics', 'বিএসসি (সম্মান) — পদার্থবিজ্ঞান', 'BSC-PHY', 'semester', 8),
  ('33333333-0000-0000-0000-000000000020', '22222222-0000-0000-0000-000000000020', 'BSc (Honours) in Statistics', 'বিএসসি (সম্মান) — পরিসংখ্যান', 'BSC-STAT', 'semester', 8),
  ('33333333-0000-0000-0000-000000000021', '22222222-0000-0000-0000-000000000021', 'BSS (Honours) in Economics', 'বিএসএস (সম্মান) — অর্থনীতি', 'BSS-ECON', 'semester', 8),
  ('33333333-0000-0000-0000-000000000022', '22222222-0000-0000-0000-000000000022', 'BSS (Honours) in Mass Communication and Journalism', 'বিএসএস (সম্মান) — গণযোগাযোগ ও সাংবাদিকতা', 'BSS-MCJ', 'semester', 8),
  ('33333333-0000-0000-0000-000000000023', '22222222-0000-0000-0000-000000000023', 'BSS (Honours) in Political Science', 'বিএসএস (সম্মান) — রাষ্ট্রবিজ্ঞান', 'BSS-POLS', 'semester', 8),
  ('33333333-0000-0000-0000-000000000024', '22222222-0000-0000-0000-000000000024', 'BSS (Honours) in Public Administration', 'বিএসএস (সম্মান) — লোকপ্রশাসন', 'BSS-PAD', 'semester', 8),
  ('33333333-0000-0000-0000-000000000025', '22222222-0000-0000-0000-000000000025', 'BSS (Honours) in Social Work', 'বিএসএস (সম্মান) — সমাজকর্ম', 'BSS-SW', 'semester', 8),
  ('33333333-0000-0000-0000-000000000026', '22222222-0000-0000-0000-000000000026', 'BSS (Honours) in Sociology', 'বিএসএস (সম্মান) — সমাজবিজ্ঞান', 'BSS-SOC', 'semester', 8)
on conflict (code) do nothing;

-- Four active undergraduate batches (1st–4th year) per program. Semester
-- system → 2 terms/year, so current_term is 1/3/5/7 for years 1–4. Batch names
-- follow "<DEPT CODE> <session>" (e.g. "CSE 2025-26"). CSE's 2025-26 batch keeps
-- its fixed UUID; the rest get gen_random_uuid().
insert into public.batches (id, program_id, admission_year, session, name, current_term, status) values
  ('44444444-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 2025, '2025-26', 'CSE 2025-26', 1, 'active')
on conflict (program_id, session) do nothing;

insert into public.batches (program_id, admission_year, session, name, current_term, status)
select p.id, y.admission_year, y.session, d.code || ' ' || y.session, y.current_term, 'active'::batch_status
from public.programs p
join public.departments d on d.id = p.department_id
cross join (values
  ('2025-26'::text, 2025::smallint, 1::smallint),
  ('2024-25',       2024::smallint, 3::smallint),
  ('2023-24',       2023::smallint, 5::smallint),
  ('2022-23',       2022::smallint, 7::smallint)
) as y(session, admission_year, current_term)
on conflict (program_id, session) do nothing;

-- ---------------------------------------------------------------------------
-- Bus routes + trips (subset mirroring university_bus_schedule_data.dart).
-- Full data set can be loaded from the app's bus schedule source later.
-- ---------------------------------------------------------------------------
insert into public.bus_routes (id, category, name, description, window_label, frequency, sort_order) values
  ('55555555-0000-0000-0000-000000000001', 'Student', 'Route 01',
   'বরিশাল ক্লাব - বাংলাবাজার মোড় - নূরিয়া স্কুল - আমতলার মোড় - রূপাতলী হাউজিং - কাঠালতলা - টোলঘর - বিশ্ববিদ্যালয়',
   '7:30 AM - 9:00 PM', 'Multiple daily trips', 1)
on conflict do nothing;

insert into public.bus_trips (route_id, departure_place, depart_time, bus_name, sort_order) values
  ('55555555-0000-0000-0000-000000000001', 'বিশ্ববিদ্যালয়', '8:30 AM', 'বৈকালি, বিআরটিসি-০৬', 1),
  ('55555555-0000-0000-0000-000000000001', 'বিশ্ববিদ্যালয়', '9:30 AM', 'চিত্রা, বিআরটিসি-০৫', 2),
  ('55555555-0000-0000-0000-000000000001', 'বরিশাল ক্লাব', '7:30 AM', 'বিআরটিসি-০৬', 3),
  ('55555555-0000-0000-0000-000000000001', 'বরিশাল ক্লাব', '8:30 AM', 'বিআরটিসি-০৪, ০৫', 4)
on conflict do nothing;
