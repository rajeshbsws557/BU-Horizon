import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../di/di.dart';
import '../models/course_offering.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/course_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Course-first attendance for the signed-in student's department and batch.
///
/// A CR remains on this same student UI. Their role only adds course and
/// attendance-session management controls; database RLS remains authoritative.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final CourseRepository _courseRepository = getIt<CourseRepository>();
  late final AttendanceRepository _attendanceRepository =
      getIt<AttendanceRepository>();
  late final SessionController _session = getIt<SessionController>();

  bool _loading = true;
  bool _mutating = false;
  String? _error;
  List<CourseOffering> _courses = const [];
  Map<String, AttendanceCourseSummary> _summaries = const {};

  bool get _isCr => _session.profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courses = await _courseRepository.fetchCourses();
      final summaries = await Future.wait(
        courses.map(
          (course) => _attendanceRepository.fetchCourseSummary(course.id),
        ),
      );
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _summaries = {
          for (final summary in summaries) summary.offeringId: summary,
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the courses for your batch.';
      });
    }
  }

  Future<void> _openCourse(CourseOffering course) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _CourseAttendanceScreen(
          course: course,
          repository: _attendanceRepository,
          session: _session,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _editCourse([CourseOffering? course]) async {
    final input = await showDialog<CourseInput>(
      context: context,
      builder: (_) => _CourseEditorDialog(course: course),
    );
    if (input == null || !mounted) return;
    setState(() => _mutating = true);
    try {
      if (course == null) {
        await _courseRepository.createCourse(input);
      } else {
        await _courseRepository.updateCourse(course.id, input);
      }
      if (!mounted) return;
      showToast(context, course == null ? 'Course added' : 'Course updated');
      await _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not save the course');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _deleteCourse(CourseOffering course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text(
          'Remove ${course.code} from this batch? Its course-scoped content '
          'will no longer be available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _mutating = true);
    try {
      await _courseRepository.deleteCourse(course.id);
      if (!mounted) return;
      showToast(context, '${course.code} deleted');
      await _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not delete the course');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _session.profile;
    final scope = [
      if (profile?.departmentName?.isNotEmpty == true) profile!.departmentName!,
      if (profile?.batchId?.isNotEmpty == true) 'your batch',
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      floatingActionButton: _isCr
          ? FloatingActionButton.extended(
              onPressed: _mutating ? null : () => _editCourse(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add course'),
            )
          : null,
      body: RefreshIndicator(
        color: context.colors.primary,
        backgroundColor: context.colors.surfaceAlt,
        onRefresh: _load,
        semanticsLabel: 'Refresh attendance courses',
        child: _loading
            ? const _CourseSkeletonList()
            : _error != null
            ? _ErrorList(message: _error!, onRetry: _load)
            : _courses.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No courses yet',
                    message: _isCr
                        ? 'Add the first course for your batch to start recording attendance.'
                        : 'Your CR has not added any courses for this batch yet.',
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: _courses.length + 1,
                separatorBuilder: (_, index) =>
                    SizedBox(height: index == 0 ? 14 : 10),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _CourseListHeader(
                      subtitle: scope.isEmpty
                          ? 'Courses assigned to your batch'
                          : scope,
                      isCr: _isCr,
                    );
                  }
                  final course = _courses[index - 1];
                  return Entrance(
                    index: index - 1,
                    child: _AttendanceCourseCard(
                      course: course,
                      summary: _summaries[course.id],
                      isCr: _isCr,
                      onTap: () => _openCourse(course),
                      onEdit: () => _editCourse(course),
                      onDelete: () => _deleteCourse(course),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CourseListHeader extends StatelessWidget {
  final String subtitle;
  final bool isCr;

  const _CourseListHeader({required this.subtitle, required this.isCr});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your courses',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isCr ? '$subtitle • CR controls enabled' : subtitle,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

enum _CourseAction { edit, delete }

class _AttendanceCourseCard extends StatelessWidget {
  final CourseOffering course;
  final AttendanceCourseSummary? summary;
  final bool isCr;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AttendanceCourseCard({
    required this.course,
    required this.summary,
    required this.isCr,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final current = summary;
    final percentage = current?.percentage ?? 0;
    final color = _attendanceColor(context, percentage, current?.total ?? 0);
    final description = current == null || current.total == 0
        ? 'No attendance recorded yet'
        : '${current.present}/${current.total} classes attended';

    return Semantics(
      button: true,
      label:
          '${course.code}, ${course.title}. $description. Open course attendance.',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: context.colors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.code,
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  current == null || current.total == 0
                      ? '—'
                      : '${(percentage * 100).round()}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isCr)
                PopupMenuButton<_CourseAction>(
                  tooltip: 'Course actions',
                  onSelected: (action) {
                    if (action == _CourseAction.edit) onEdit();
                    if (action == _CourseAction.delete) onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _CourseAction.edit,
                      child: Text('Edit course'),
                    ),
                    PopupMenuItem(
                      value: _CourseAction.delete,
                      child: Text('Delete course'),
                    ),
                  ],
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseAttendanceScreen extends StatefulWidget {
  final CourseOffering course;
  final AttendanceRepository repository;
  final SessionController session;

  const _CourseAttendanceScreen({
    required this.course,
    required this.repository,
    required this.session,
  });

  @override
  State<_CourseAttendanceScreen> createState() =>
      _CourseAttendanceScreenState();
}

class _CourseAttendanceScreenState extends State<_CourseAttendanceScreen> {
  bool _loading = true;
  String? _error;
  AttendanceCourseSummary? _summary;
  List<AttendanceSession> _sessions = const [];

  bool get _isCr => widget.session.profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        widget.repository.fetchCourseSummary(widget.course.id),
        widget.repository.fetchCourseSessions(widget.course.id),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as AttendanceCourseSummary;
        _sessions = results[1] as List<AttendanceSession>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load attendance for this course.';
      });
    }
  }

  Future<void> _openEditor([AttendanceSession? session]) async {
    if (!_isCr) {
      showToast(context, 'CR access is no longer active');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AttendanceEditorScreen(
          course: widget.course,
          repository: widget.repository,
          sessionController: widget.session,
          session: session,
        ),
      ),
    );
    if (saved == true && mounted) {
      showToast(
        context,
        session == null ? 'Attendance recorded' : 'Attendance updated',
      );
      await _load();
    }
  }

  Future<void> _delete(AttendanceSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete attendance?'),
        content: Text(
          'Delete the class on ${DateFormat('MMM d, yyyy').format(session.date)} '
          'and every attendance record saved for it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteSession(session.id);
      if (!mounted) return;
      showToast(context, 'Attendance deleted');
      await _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not delete attendance');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final isCr = _isCr;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(widget.course.code),
                Text(
                  'Attendance',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: isCr
              ? FloatingActionButton.extended(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: const Text('Record attendance'),
                )
              : null,
          body: RefreshIndicator(
            color: context.colors.primary,
            backgroundColor: context.colors.surfaceAlt,
            onRefresh: _load,
            child: _loading
                ? const _SessionSkeletonList()
                : _error != null
                ? _ErrorList(message: _error!, onRetry: _load)
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                    children: [
                      _AttendanceSummaryCard(
                        course: widget.course,
                        summary: _summary!,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Class history',
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${_sessions.length} ${_sessions.length == 1 ? 'class' : 'classes'}',
                            style: TextStyle(
                              color: context.colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_sessions.isEmpty)
                        EmptyState(
                          icon: Icons.fact_check_outlined,
                          title: 'No attendance yet',
                          message: isCr
                              ? 'Record the first class attendance for this course.'
                              : 'Your CR has not recorded a class for this course yet.',
                        )
                      else
                        ...List.generate(
                          _sessions.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Entrance(
                              index: index,
                              child: _AttendanceSessionCard(
                                session: _sessions[index],
                                isCr: isCr,
                                onEdit: () => _openEditor(_sessions[index]),
                                onDelete: () => _delete(_sessions[index]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  final CourseOffering course;
  final AttendanceCourseSummary summary;

  const _AttendanceSummaryCard({required this.course, required this.summary});

  @override
  Widget build(BuildContext context) {
    final percentage = summary.percentage;
    final color = _attendanceColor(context, percentage, summary.total);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (course.teacherName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              course.teacherName,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                summary.total == 0 ? '—' : '${(percentage * 100).round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  summary.total == 0
                      ? 'No classes recorded'
                      : '${summary.present} present • ${summary.total - summary.present} absent',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.total == 0 ? 0 : percentage,
              minHeight: 7,
              backgroundColor: context.colors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SessionAction { edit, delete }

class _AttendanceSessionCard extends StatelessWidget {
  final AttendanceSession session;
  final bool isCr;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AttendanceSessionCard({
    required this.session,
    required this.isCr,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = session.status;
    final statusColor = switch (status) {
      AttendanceMark.present => context.colors.success,
      AttendanceMark.absent => context.colors.danger,
      null => context.colors.textMuted,
    };
    final statusLabel = switch (status) {
      AttendanceMark.present => 'Present',
      AttendanceMark.absent => 'Absent',
      null => 'Not recorded',
    };
    final time = _timeRange(session.startTime, session.endTime);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(session.date),
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('MMM').format(session.date).toUpperCase(),
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.topic.isEmpty ? 'Class session' : session.topic,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    DateFormat('EEEE').format(session.date),
                    if (time.isNotEmpty) time,
                  ].join(' • '),
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (isCr && session.recordCount != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${session.presentCount ?? 0}/${session.recordCount} students present',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isCr)
            PopupMenuButton<_SessionAction>(
              tooltip: 'Attendance actions',
              onSelected: (action) {
                if (action == _SessionAction.edit) onEdit();
                if (action == _SessionAction.delete) onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _SessionAction.edit,
                  child: Text('Edit attendance'),
                ),
                PopupMenuItem(
                  value: _SessionAction.delete,
                  child: Text('Delete attendance'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AttendanceEditorScreen extends StatefulWidget {
  final CourseOffering course;
  final AttendanceRepository repository;
  final SessionController sessionController;
  final AttendanceSession? session;

  const _AttendanceEditorScreen({
    required this.course,
    required this.repository,
    required this.sessionController,
    this.session,
  });

  @override
  State<_AttendanceEditorScreen> createState() =>
      _AttendanceEditorScreenState();
}

class _AttendanceEditorScreenState extends State<_AttendanceEditorScreen> {
  late DateTime _date = widget.session?.date ?? DateTime.now();
  late String? _startTime = widget.session?.startTime;
  late String? _endTime = widget.session?.endTime;
  late final TextEditingController _topicController = TextEditingController(
    text: widget.session?.topic ?? '',
  );

  bool _loading = true;
  bool _saving = false;
  bool _closingForRoleChange = false;
  String? _error;
  List<AttendanceRosterMember> _members = const [];
  final Map<String, AttendanceMark?> _marks = {};

  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_roleChanged);
    if (_isCr) {
      _loadRoster();
    } else {
      _roleChanged();
    }
  }

  bool get _isCr =>
      widget.sessionController.profile?.role.toLowerCase() == 'cr';

  void _roleChanged() {
    if (_isCr || _closingForRoleChange || !mounted) return;
    _closingForRoleChange = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showToast(context, 'CR access is no longer active');
      Navigator.of(context).pop(false);
    });
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_roleChanged);
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await widget.repository.fetchSessionRoster(
        offeringId: widget.course.id,
        sessionId: widget.session?.id,
      );
      if (!mounted) return;
      setState(() {
        _members = members;
        _marks
          ..clear()
          ..addEntries(
            members.map((member) => MapEntry(member.profileId, member.status)),
          );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the batch roster.';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final raw = start ? _startTime : _endTime;
    final initial = _parseTime(raw) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    final value = _storeTime(picked);
    setState(() {
      if (start) {
        _startTime = value;
      } else {
        _endTime = value;
      }
    });
  }

  void _markAll(AttendanceMark mark) {
    setState(() {
      for (final member in _members) {
        _marks[member.profileId] = mark;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_isCr) {
      showToast(context, 'CR access is no longer active');
      return;
    }
    if (_members.isEmpty) {
      showToast(context, 'There are no active students in this batch');
      return;
    }
    final missing = _members
        .where((member) => _marks[member.profileId] == null)
        .length;
    if (missing > 0) {
      showToast(context, 'Mark all $missing remaining students');
      return;
    }
    if (_startTime != null &&
        _endTime != null &&
        _minutes(_endTime!) <= _minutes(_startTime!)) {
      showToast(context, 'End time must be after start time');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.saveSession(
        AttendanceSessionDraft(
          offeringId: widget.course.id,
          sessionId: widget.session?.id,
          date: _date,
          startTime: _startTime,
          endTime: _endTime,
          topic: _topicController.text,
          records: {
            for (final member in _members)
              member.profileId: _marks[member.profileId]!,
          },
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showToast(context, 'Could not save attendance');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final marked = _marks.values.whereType<AttendanceMark>().length;
    final present = _marks.values
        .where((mark) => mark == AttendanceMark.present)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.session == null ? 'Record attendance' : 'Edit attendance',
        ),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorList(message: _error!, onRetry: _loadRoster)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  '${widget.course.code} • ${widget.course.title}',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                _EditorField(
                  label: 'Class date',
                  value: DateFormat('EEEE, MMM d, yyyy').format(_date),
                  icon: Icons.calendar_today_rounded,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _EditorField(
                        label: 'Start time',
                        value: _displayTime(_startTime) ?? 'Optional',
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickTime(start: true),
                        onClear: _startTime == null
                            ? null
                            : () => setState(() => _startTime = null),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _EditorField(
                        label: 'End time',
                        value: _displayTime(_endTime) ?? 'Optional',
                        icon: Icons.schedule_rounded,
                        onTap: () => _pickTime(start: false),
                        onClear: _endTime == null
                            ? null
                            : () => setState(() => _endTime = null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _topicController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Topic (optional)',
                    hintText: 'What was covered?',
                    prefixIcon: Icon(Icons.subject_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batch roster',
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$marked/${_members.length} marked • $present present',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<AttendanceMark>(
                      tooltip: 'Mark all students',
                      onSelected: _markAll,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: AttendanceMark.present,
                          child: Text('Mark all present'),
                        ),
                        PopupMenuItem(
                          value: AttendanceMark.absent,
                          child: Text('Mark all absent'),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          'Mark all',
                          style: TextStyle(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_members.isEmpty)
                  const EmptyState(
                    icon: Icons.group_off_outlined,
                    title: 'No students found',
                    message: 'This batch has no active student roster yet.',
                  )
                else
                  ..._members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _RosterRow(
                        member: member,
                        mark: _marks[member.profileId],
                        onChanged: (mark) =>
                            setState(() => _marks[member.profileId] = mark),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  final AttendanceRosterMember member;
  final AttendanceMark? mark;
  final ValueChanged<AttendanceMark> onChanged;

  const _RosterRow({
    required this.member,
    required this.mark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                if (member.identifier.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.identifier,
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MarkButton(
            label: 'P',
            tooltip: 'Present',
            selected: mark == AttendanceMark.present,
            color: context.colors.success,
            onTap: () => onChanged(AttendanceMark.present),
          ),
          const SizedBox(width: 6),
          _MarkButton(
            label: 'A',
            tooltip: 'Absent',
            selected: mark == AttendanceMark.absent,
            color: context.colors.danger,
            onTap: () => onChanged(AttendanceMark.absent),
          ),
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _MarkButton({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _EditorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Clear $label',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 13),
        ),
      ),
    );
  }
}

class _CourseEditorDialog extends StatefulWidget {
  final CourseOffering? course;

  const _CourseEditorDialog({this.course});

  @override
  State<_CourseEditorDialog> createState() => _CourseEditorDialogState();
}

class _CourseEditorDialogState extends State<_CourseEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.course?.code ?? '',
  );
  late final TextEditingController _title = TextEditingController(
    text: widget.course?.title ?? '',
  );
  late final TextEditingController _teacher = TextEditingController(
    text: widget.course?.teacherName ?? '',
  );
  late final TextEditingController _credit = TextEditingController(
    text: widget.course?.creditHours?.toString() ?? '',
  );
  late final TextEditingController _term = TextEditingController(
    text: widget.course?.termNumber?.toString() ?? '',
  );

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _teacher.dispose();
    _credit.dispose();
    _term.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CourseInput(
        code: _code.text.trim().toUpperCase(),
        title: _title.text.trim(),
        teacherName: _teacher.text.trim(),
        creditHours: _credit.text.trim().isEmpty
            ? null
            : double.parse(_credit.text.trim()),
        termNumber: _term.text.trim().isEmpty
            ? null
            : int.parse(_term.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.course == null ? 'Add course' : 'Edit course'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Course code'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a course code'
                      : null,
                ),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Course title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a course title'
                      : null,
                ),
                TextFormField(
                  controller: _teacher,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Teacher (optional)',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _credit,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Credits'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final credit = double.tryParse(value.trim());
                          return credit == null || credit < 0
                              ? 'Invalid'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _term,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Term'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final term = int.tryParse(value.trim());
                          return term == null || term < 1 ? 'Invalid' : null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ErrorList extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorList({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Something went wrong',
          message: message,
        ),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

class _CourseSkeletonList extends StatelessWidget {
  const _CourseSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: const Row(
          children: [
            Skeleton(
              width: 44,
              height: 44,
              radius: BorderRadius.all(Radius.circular(12)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 70, height: 11),
                  SizedBox(height: 7),
                  Skeleton(width: 190, height: 14),
                  SizedBox(height: 7),
                  Skeleton(width: 130, height: 11),
                ],
              ),
            ),
            Skeleton(width: 42, height: 28),
          ],
        ),
      ),
    );
  }
}

class _SessionSkeletonList extends StatelessWidget {
  const _SessionSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => Skeleton(
        height: index == 0 ? 150 : 76,
        radius: const BorderRadius.all(Radius.circular(14)),
      ),
    );
  }
}

Color _attendanceColor(BuildContext context, double percentage, int total) {
  if (total == 0) return context.colors.textMuted;
  if (percentage >= 0.75) return context.colors.success;
  if (percentage < 0.60) return context.colors.danger;
  return context.colors.warning;
}

String _timeRange(String? start, String? end) {
  final parts = [
    if (_displayTime(start) != null) _displayTime(start)!,
    if (_displayTime(end) != null) _displayTime(end)!,
  ];
  return parts.join(' – ');
}

String? _displayTime(String? raw) {
  final time = _parseTime(raw);
  if (time == null) return null;
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

TimeOfDay? _parseTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _storeTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

int _minutes(String raw) {
  final time = _parseTime(raw);
  return time == null ? -1 : time.hour * 60 + time.minute;
}
