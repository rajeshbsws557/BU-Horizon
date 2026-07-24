// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../supabase/supabase_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Data models for Club Screen
class ClubInfoData {
  final String name;
  final String tagline;
  final String description;
  final String foundingYear;
  final String contactEmail;
  final int totalMembers;
  final int activeProjects;
  final int totalEvents;

  const ClubInfoData({
    required this.name,
    required this.tagline,
    required this.description,
    required this.foundingYear,
    required this.contactEmail,
    required this.totalMembers,
    required this.activeProjects,
    required this.totalEvents,
  });

  factory ClubInfoData.fromJson(Map<String, dynamic> json) {
    return ClubInfoData(
      name:
          json['name'] as String? ??
          'BU ISSF (Barishal University Intelligent Systems & Security Forum)',
      tagline:
          json['tagline'] as String? ??
          'Innovating, Securing, and Building the Future of Intelligent Systems at Barishal University',
      description:
          json['description'] as String? ??
          'BU ISSF is the premier student forum of the University of Barishal dedicated to Artificial Intelligence, Machine Learning, Cybersecurity, Cloud Computing, and Software Engineering. Founded to foster collaborative research and practical engineering skills, we organize hackathons, technical bootcamps, and cybersecurity drills.',
      foundingYear: json['founding_year'] as String? ?? '2023',
      contactEmail: json['contact_email'] as String? ?? 'issf@bu.ac.bd',
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 150,
      activeProjects: (json['active_projects'] as num?)?.toInt() ?? 18,
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 32,
    );
  }

  static const ClubInfoData defaultInfo = ClubInfoData(
    name: 'BU ISSF (Barishal University Intelligent Systems & Security Forum)',
    tagline:
        'Innovating, Securing, and Building the Future of Intelligent Systems at Barishal University',
    description:
        'BU ISSF is the premier student forum of the University of Barishal dedicated to Artificial Intelligence, Machine Learning, Cybersecurity, Cloud Computing, and Software Engineering. Founded to foster collaborative research and practical engineering skills, we organize hackathons, technical bootcamps, and cybersecurity drills.',
    foundingYear: '2023',
    contactEmail: 'issf@bu.ac.bd',
    totalMembers: 150,
    activeProjects: 18,
    totalEvents: 32,
  );
}

class ClubMemberData {
  final String name;
  final String designation;
  final String roleType;
  final String department;
  final String batch;
  final String? email;
  final bool isActive;

  const ClubMemberData({
    required this.name,
    required this.designation,
    required this.roleType,
    required this.department,
    required this.batch,
    this.email,
    required this.isActive,
  });

  factory ClubMemberData.fromJson(Map<String, dynamic> json) {
    return ClubMemberData(
      name: json['name'] as String? ?? 'Member',
      designation: json['designation'] as String? ?? 'General Member',
      roleType: json['role_type'] as String? ?? 'executive',
      department:
          json['department'] as String? ?? 'Computer Science and Engineering',
      batch: json['batch'] as String? ?? '10th Batch',
      email: json['email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  static const List<ClubMemberData> defaultMembers = [
    ClubMemberData(
      name: 'Md. Tanvir Ahmed',
      designation: 'President',
      roleType: 'executive',
      department: 'Computer Science and Engineering',
      batch: '9th Batch',
      email: 'tanvir.issf@bu.ac.bd',
      isActive: true,
    ),
    ClubMemberData(
      name: 'Nusrat Jahan Ananya',
      designation: 'Vice President',
      roleType: 'executive',
      department: 'Computer Science and Engineering',
      batch: '9th Batch',
      email: 'ananya.issf@bu.ac.bd',
      isActive: true,
    ),
    ClubMemberData(
      name: 'S. M. Shahriar Rahman',
      designation: 'General Secretary',
      roleType: 'executive',
      department: 'Computer Science and Engineering',
      batch: '10th Batch',
      email: 'shahriar.issf@bu.ac.bd',
      isActive: true,
    ),
    ClubMemberData(
      name: 'Tahsin Kazi',
      designation: 'Treasurer & Finance Lead',
      roleType: 'executive',
      department: 'Department of Management',
      batch: '10th Batch',
      email: 'tahsin.issf@bu.ac.bd',
      isActive: true,
    ),
    ClubMemberData(
      name: 'Abrar Fahad',
      designation: 'Lead Cybersecurity Analyst',
      roleType: 'core',
      department: 'Computer Science and Engineering',
      batch: '10th Batch',
      email: 'abrar.issf@bu.ac.bd',
      isActive: true,
    ),
    ClubMemberData(
      name: 'Fariha Tasnim',
      designation: 'AI & Machine Learning Coordinator',
      roleType: 'core',
      department: 'Computer Science and Engineering',
      batch: '11th Batch',
      email: 'fariha.issf@bu.ac.bd',
      isActive: true,
    ),
  ];
}

class ClubActivityData {
  final String title;
  final String description;
  final String category;
  final String activityDate;
  final String location;
  final bool isFeatured;

  const ClubActivityData({
    required this.title,
    required this.description,
    required this.category,
    required this.activityDate,
    required this.location,
    required this.isFeatured,
  });

  factory ClubActivityData.fromJson(Map<String, dynamic> json) {
    return ClubActivityData(
      title: json['title'] as String? ?? 'Activity',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Workshop',
      activityDate: json['activity_date'] as String? ?? 'Recent Semester',
      location: json['location'] as String? ?? 'BU Campus',
      isFeatured: json['is_featured'] as bool? ?? true,
    );
  }

  static const List<ClubActivityData> defaultActivities = [
    ClubActivityData(
      title: 'National Cybersecurity Flag Capture (CTF) Bootcamp',
      description:
          'Intensive 3-day hands-on bootcamp focusing on penetration testing, network forensics, and reverse engineering. Participants competed in real-time red-team/blue-team scenarios.',
      category: 'Hackathon',
      activityDate: '2026 Semester 1',
      location: 'Computer Lab 2, Academic Building',
      isFeatured: true,
    ),
    ClubActivityData(
      title: 'Applied Deep Learning & Neural Networks Workshop',
      description:
          'Comprehensive hands-on training covering PyTorch, Transformer architectures, and fine-tuning Large Language Models for academic and industrial problem solving.',
      category: 'Workshop',
      activityDate: 'Summer 2026',
      location: 'Central Auditorium',
      isFeatured: true,
    ),
    ClubActivityData(
      title: 'Open Source Contribution & Git Bootcamp',
      description:
          'Introductory bootcamp designed to transition junior engineering students into active open source contributors, covering version control, pull requests, and CI/CD basics.',
      category: 'Seminar',
      activityDate: 'Fall 2025',
      location: 'Academic Building 1, Room 302',
      isFeatured: true,
    ),
    ClubActivityData(
      title: 'Ethical Hacking & Web Penetration Testing Drill',
      description:
          'Weekly interactive study circle testing vulnerabilities in sandbox environments using industry-standard penetration tools and OWASP guidelines.',
      category: 'Study Group',
      activityDate: 'Ongoing Weekly',
      location: 'Virtual & CSE Lab 3',
      isFeatured: false,
    ),
  ];
}

class ClubNoticeData {
  final String title;
  final String subtitle;
  final String body;
  final String category;
  final String priority;
  final bool isPinned;

  const ClubNoticeData({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.category,
    required this.priority,
    required this.isPinned,
  });

  factory ClubNoticeData.fromJson(Map<String, dynamic> json) {
    return ClubNoticeData(
      title: json['title'] as String? ?? 'Notice',
      subtitle: json['subtitle'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'normal',
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }

  static const List<ClubNoticeData> defaultNotices = [
    ClubNoticeData(
      title: 'Call for Executive Committee Nominations 2026-2027',
      subtitle:
          'Applications are now open for leadership roles in the upcoming tenure.',
      body:
          'BU ISSF invites passionate and dedicated members from all departments to submit their applications for executive and core leadership positions for the 2026-2027 tenure. Candidates must demonstrate active participation in forum activities and strong technical/leadership acumen.\n\nDeadline: August 15, 2026.',
      category: 'Recruitment',
      priority: 'high',
      isPinned: true,
    ),
    ClubNoticeData(
      title: 'Upcoming AI & Cybersecurity Hackathon Registration Open',
      subtitle:
          'Form your teams of 3-4 and register for the campus-wide hackathon.',
      body:
          'Registration is live for the Barishal University Tech Odyssey 2026! Compete in AI solution tracks or cybersecurity defense challenges for prize money and mentorship opportunities.\n\nVisit the forum office or check our online portal to submit your team rosters.',
      category: 'Event',
      priority: 'normal',
      isPinned: true,
    ),
    ClubNoticeData(
      title:
          'Weekly Study Circle: Introduction to Cryptography & Zero-Knowledge Proofs',
      subtitle: 'Join us this Thursday at 4:00 PM in Lab 3.',
      body:
          'Our weekly technical meetup will explore modern cryptographic foundations, elliptic curve cryptography, and practical applications of Zero-Knowledge Proofs (ZKPs) in blockchain and privacy-preserving protocols. Open to all students.',
      category: 'Academic',
      priority: 'normal',
      isPinned: false,
    ),
  ];
}

class ClubScreen extends StatefulWidget {
  const ClubScreen({super.key});

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  ClubInfoData _info = ClubInfoData.defaultInfo;
  List<ClubMemberData> _members = ClubMemberData.defaultMembers;
  List<ClubActivityData> _activities = ClubActivityData.defaultActivities;
  List<ClubNoticeData> _notices = ClubNoticeData.defaultNotices;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchClubData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchClubData() async {
    setState(() => _isLoading = true);
    try {
      if (SupabaseConfig.isConfigured) {
        final client = Supabase.instance.client;

        // Fetch Club Info
        final infoRow = await client
            .from('club_info')
            .select()
            .limit(1)
            .maybeSingle();
        if (infoRow != null) {
          _info = ClubInfoData.fromJson(infoRow);
        }

        // Fetch Members
        final membersRows = await client
            .from('club_members')
            .select()
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        if (membersRows.isNotEmpty) {
          _members = membersRows
              .map((row) => ClubMemberData.fromJson(row))
              .toList();
        }

        // Fetch Activities
        final activitiesRows = await client
            .from('club_activities')
            .select()
            .order('sort_order', ascending: true);
        if (activitiesRows.isNotEmpty) {
          _activities = activitiesRows
              .map((row) => ClubActivityData.fromJson(row))
              .toList();
        }

        // Fetch Notices
        final noticesRows = await client
            .from('club_notices')
            .select()
            .order('is_pinned', ascending: false)
            .order('published_at', ascending: false);
        if (noticesRows.isNotEmpty) {
          _notices = noticesRows
              .map((row) => ClubNoticeData.fromJson(row))
              .toList();
        }
      }
    } catch (_) {
      // Graceful fallback to default seed data if network offline / unauth
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: ResponsivePage(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 260.0,
                floating: false,
                pinned: true,
                elevation: 0,
                backgroundColor: colors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: colors.heroGradient,
                        ),
                      ),
                      Positioned(
                        right: -30,
                        top: -20,
                        child: Icon(
                          Icons.hub_rounded,
                          size: 220,
                          color: colors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 62),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'EST. ${_info.foundingYear} · PREMIER TECH FORUM',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _info.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _info.tagline,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: colors.primary,
                  indicatorWeight: 3,
                  labelColor: colors.primary,
                  unselectedLabelColor: colors.textMuted,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Members'),
                    Tab(text: 'Activities'),
                    Tab(text: 'Notices'),
                  ],
                ),
              ),
            ];
          },
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetchClubData,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(colors),
                      _buildMembersTab(colors),
                      _buildActivitiesTab(colors),
                      _buildNoticesTab(colors),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(AppThemeColors colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                colors,
                'Members',
                '${_info.totalMembers}+',
                Icons.groups_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                colors,
                'Projects',
                '${_info.activeProjects}+',
                Icons.code_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                colors,
                'Events',
                '${_info.totalEvents}+',
                Icons.event_available_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'About BU ISSF',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _info.description,
                style: TextStyle(
                  fontSize: 14.5,
                  color: colors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: colors.border.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _launchEmail(_info.contactEmail),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 18,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Official Contact: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _info.contactEmail,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Core Focus Areas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildFocusChip(
              colors,
              'Artificial Intelligence',
              Icons.psychology_rounded,
            ),
            _buildFocusChip(
              colors,
              'Cybersecurity & CTF',
              Icons.security_rounded,
            ),
            _buildFocusChip(colors, 'Cloud & DevOps', Icons.cloud_done_rounded),
            _buildFocusChip(
              colors,
              'Machine Learning',
              Icons.model_training_rounded,
            ),
            _buildFocusChip(
              colors,
              'Full-Stack Engineering',
              Icons.terminal_rounded,
            ),
            _buildFocusChip(
              colors,
              'Research & Publications',
              Icons.menu_book_rounded,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMetricCard(
    AppThemeColors colors,
    String label,
    String val,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusChip(AppThemeColors colors, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open mail app for $email')),
        );
      }
    }
  }

  String _getMemberInitial(String name) {
    const honorifics = {'md.', 's.', 'm.', 'dr.', 'mr.', 'ms.', 'mrs.'};
    for (final part in name.trim().split(RegExp(r'\s+'))) {
      if (!honorifics.contains(part.toLowerCase())) {
        return part.substring(0, 1).toUpperCase();
      }
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'M';
  }

  Widget _buildMembersTab(AppThemeColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isPresident = member.designation.toLowerCase().contains(
          'president',
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPresident
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isPresident
                      ? LinearGradient(
                          colors: [colors.primary, colors.accentCyan],
                        )
                      : null,
                  color: colors.surfaceAlt,
                ),
                alignment: Alignment.center,
                child: Text(
                  _getMemberInitial(member.name),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isPresident ? Colors.white : colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (isPresident) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.stars_rounded,
                            size: 16,
                            color: colors.gold,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.designation,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.department} · ${member.batch}',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitiesTab(AppThemeColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _activities.length,
      itemBuilder: (context, index) {
        final act = _activities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: act.isFeatured
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      act.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            act.activityDate,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                act.title,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                act.description,
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 15,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    act.location,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticesTab(AppThemeColors colors) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notice.isPinned
                  ? colors.primary.withValues(alpha: 0.4)
                  : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (notice.isPinned) ...[
                    Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PINNED NOTICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  if (notice.priority.toLowerCase() == 'high') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            size: 12,
                            color: colors.danger,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'HIGH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: colors.danger,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notice.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                notice.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              if (notice.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  notice.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                notice.body,
                style: TextStyle(
                  fontSize: 13.5,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
