import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/di.dart';
import '../models/course_offering.dart';
import '../models/models.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/course_repository.dart';
import '../repositories/exam_repository.dart';
import '../repositories/notice_repository.dart';
import '../repositories/resource_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/course_catalog.dart';
import '../widgets/motion.dart';
import '../widgets/pending_approval_view.dart';
import '../widgets/term_history_sheet.dart';


import 'exam_schedule_screen.dart';
import 'resources_screen.dart';

/// Course-first class notices for the signed-in student's batch.
///
/// A CR sees this exact student UI with contextual create/edit/delete controls.
class ClassNoticesScreen extends StatefulWidget {
  const ClassNoticesScreen({super.key});

  @override
  State<ClassNoticesScreen> createState() => _ClassNoticesScreenState();
}

class _ClassNoticesScreenState extends State<ClassNoticesScreen> {
  late final CourseRepository _coursesRepository = getIt<CourseRepository>();
  bool _loading = true;
  bool _mutating = false;
  List<CourseOffering> _courses = const [];
  String? _error;
  DateTime? _lastUpdatedAt;

  /// This screen owns term selection so the semester-history button can live in
  /// the AppBar (top-right, just left of the "+" for CRs), per product spec.
  int? _selectedTerm;

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  Future<void> _openHistory() async {
    final profile = getIt<SessionController>().profile;
    final termLabel = profile?.termLabel ?? 'Semester';
    final currentTerm = profile?.currentTerm;
    final availableTerms = CourseCatalogView.availableTermsFor(
      courses: _courses,
      currentTerm: currentTerm,
    );
    final picked = await showTermHistorySheet(
      context,
      availableTerms: availableTerms,
      selectedTerm: _selectedTerm,
      currentTerm: currentTerm,
      termLabel: termLabel,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTerm = picked);
    }
  }


  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    // Keep an already-loaded catalog on screen while refreshing; only the very
    // first read shows skeletons.
    if (mounted) {
      setState(() {
        _loading = _courses.isEmpty;
        _error = null;
      });
    }
    try {
      final courses = await _coursesRepository.fetchCourses();
      if (!mounted) return;
      // This screen owns term selection (controlled mode), so CourseCatalogView
      // will NOT auto-default the term for us. Initialize it to the student's
      // current term here so notices for the current semester show by default —
      // otherwise the list stays empty until a term is picked from history.
      final currentTerm = getIt<SessionController>().profile?.currentTerm;
      final availableTerms = CourseCatalogView.availableTermsFor(
        courses: courses,
        currentTerm: currentTerm,
      );
      setState(() {
        _courses = courses;
        // Only (re)initialize when unset or no longer valid; never overwrite a
        // term the student deliberately picked from the history sheet.
        if (_selectedTerm == null ||
            !availableTerms.contains(_selectedTerm)) {
          _selectedTerm =
              currentTerm != null && availableTerms.contains(currentTerm)
                  ? currentTerm
                  : (availableTerms.isNotEmpty ? availableTerms.last : null);
        }
        _loading = false;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your batch courses.';
      });
    }
  }


  Future<void> _addCourse() async {
    final input = await showCourseEditorSheet(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _coursesRepository.createCourse(input),
      successMessage: 'Course added for your batch',
    );
  }

  Future<void> _editCourse(CourseOffering course) async {
    final input = await showCourseEditorSheet(context, course: course);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _coursesRepository.updateCourse(course.id, input),
      successMessage: 'Course updated',
    );
  }

  Future<void> _deleteCourse(CourseOffering course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete course?'),
        content: Text(
          '${course.code} will be removed from this batch. Its notices, '
          'resources and attendance will no longer appear in the student app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => _coursesRepository.deleteCourse(course.id),
      successMessage: 'Course removed',
    );
  }

  Future<void> _runMutation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await operation();
      if (!mounted) return;
      showToast(context, successMessage);
      await _loadCourses();
    } catch (_) {
      if (mounted) showToast(context, 'Could not save that change');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _openCourse(CourseOffering course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CourseHubScreen(course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: getIt<SessionController>(),
      builder: (context, _) {
        final canManage = _canManage;
        final isPending =
            getIt<SessionController>().profile?.isPendingVerification == true;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Class Notices',
              style: TextStyle(color: context.colors.textPrimary),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: context.colors.textPrimary),
            actions: [
              // Pending students can't browse batch content, so hide the
              // history/add actions for them.
              if (!isPending) ...[
                // Semester history lives top-right per product spec — and, for a
                // CR, immediately left of the "+" add button.
                IconButton(
                  onPressed: _openHistory,
                  tooltip: 'Semester history',
                  icon: const Icon(Icons.history_rounded),
                ),
                if (canManage)
                  IconButton(
                    onPressed: _mutating ? null : _addCourse,
                    tooltip: 'Add course',
                    icon: const Icon(Icons.add_rounded),
                  ),
              ],
            ],
          ),
          body: isPending
              ? const PendingApprovalView(featureName: 'class notices')
              : CourseCatalogView(

            isLoading: _loading,
            canManage: canManage,
            courses: _courses,
            featureName: 'class notices',
            emptyIcon: Icons.campaign_outlined,
            onRefresh: _loadCourses,
            onOpen: _openCourse,
            onEdit: canManage ? _editCourse : null,
            onDelete: canManage ? _deleteCourse : null,
            errorMessage: _error,
            lastUpdatedAt: _lastUpdatedAt,
            // Controlled term selection: the screen owns the term (defaulted to
            // the student's current term in _loadCourses) and renders the
            // history button in the AppBar, so the current semester's notices
            // show by default without any manual selection.
            selectedTerm: _selectedTerm,
            onTermSelected: (term) => setState(() => _selectedTerm = term),
          ),
        );
      },
    );
  }
}

class _CourseHubScreen extends StatefulWidget {
  final CourseOffering course;

  const _CourseHubScreen({required this.course});

  @override
  State<_CourseHubScreen> createState() => _CourseHubScreenState();
}

class _CourseHubScreenState extends State<_CourseHubScreen>
    with SingleTickerProviderStateMixin {
  late final NoticeRepository _noticeRepo = getIt<NoticeRepository>();
  late final ResourceRepository _resourceRepo = getIt<ResourceRepository>();
  late final ExamRepository _examRepo = getIt<ExamRepository>();
  late final AttendanceRepository _attendanceRepo =
      getIt<AttendanceRepository>();

  late final TabController _tabController;

  bool _loading = true;
  bool _mutating = false;
  String? _error;
  DateTime? _lastUpdatedAt;

  // Data sources
  AttendanceCourseSummary? _attendance;
  List<ClassNotice> _notices = const [];
  List<ResourceItem> _resources = const [];
  List<ExamItem> _exams = const [];

  /// True when nothing has ever loaded for this course, so a failed read has no
  /// stale content to fall back to.
  bool get _isEmpty =>
      _attendance == null &&
      _notices.isEmpty &&
      _resources.isEmpty &&
      _exams.isEmpty;

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = _isEmpty;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _attendanceRepo.fetchCourseSummary(widget.course.id),
        _noticeRepo.fetchCourseNotices(widget.course.id),
        _resourceRepo.fetchResources(offeringId: widget.course.id),
        _examRepo.fetchCourseExams(widget.course.id),
      ]);
      if (!mounted) return;
      setState(() {
        _attendance = results[0] as AttendanceCourseSummary;
        _notices = results[1] as List<ClassNotice>;
        _resources = results[2] as List<ResourceItem>;
        _exams = results[3] as List<ExamItem>;
        _loading = false;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this course’s notices, resources and exams.';
      });
    }
  }

  // ── Notice mutations ──────────────────────────────────────────────────

  Future<void> _addNotice() async {
    final input = await _showNoticeEditor(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _noticeRepo.createCourseNotice(
        offeringId: widget.course.id,
        title: input.title,
        body: input.body,
        category: input.category,
        isPinned: input.isPinned,
      ),
      successMessage: 'Class notice published',
    );
  }

  Future<void> _editNotice(ClassNotice notice) async {
    final input = await _showNoticeEditor(context, notice: notice);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _noticeRepo.updateCourseNotice(
        noticeId: notice.id,
        title: input.title,
        body: input.body,
        category: input.category,
        isPinned: input.isPinned,
      ),
      successMessage: 'Class notice updated',
    );
  }

  Future<void> _deleteNotice(ClassNotice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notice?'),
        content: Text('"${notice.title}" will no longer be visible to students.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => _noticeRepo.deleteCourseNotice(notice.id),
      successMessage: 'Class notice deleted',
    );
  }

  Future<void> _addResource() async {
    final input = await showResourceEditorSheet(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _resourceRepo.createResource(
        offeringId: widget.course.id,
        title: input.title,
        description: input.description,
        kind: input.kind,
        url: input.url,
        upload: input.upload,
      ),
      successMessage: 'Resource shared',
    );
  }

  Future<void> _editResource(ResourceItem resource) async {
    final input = await showResourceEditorSheet(context, resource: resource);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _resourceRepo.updateResource(
        resourceId: resource.id,
        title: input.title,
        description: input.description,
        kind: input.kind,
        url: input.url,
        upload: input.upload,
        keepExistingUpload: input.keepExistingUpload,
      ),
      successMessage: 'Resource updated',
    );
  }

  Future<void> _deleteResource(ResourceItem resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('Are you sure you want to delete "${resource.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => _resourceRepo.deleteResource(resource.id),
      successMessage: 'Resource deleted',
    );
  }

  Future<void> _addExam() async {
    final input = await showExamEditorSheet(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _examRepo.createExam(
        offeringId: widget.course.id,
        input: input,
      ),
      successMessage: 'Exam notice published',
    );
  }

  Future<void> _editExam(ExamItem exam) async {
    final input = await showExamEditorSheet(context, exam: exam);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _examRepo.updateExam(
        examId: exam.id,
        input: input,
      ),
      successMessage: 'Exam notice updated',
    );
  }

  Future<void> _deleteExam(ExamItem exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exam Notice?'),
        content: Text('Are you sure you want to delete "${exam.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => _examRepo.deleteExam(exam.id),
      successMessage: 'Exam notice deleted',
    );
  }

  // ── Shared mutation runner ─────────────────────────────────────────────

  Future<void> _runMutation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await operation();
      if (!mounted) return;
      showToast(context, successMessage);
      await _loadAll();
    } catch (_) {
      if (mounted) showToast(context, 'Could not save that change');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  // ── FAB for active tab ────────────────────────────────────────────────

  Widget? _buildFab(bool canManage) {
    if (!canManage) return null;
    final tab = _tabController.index;
    final (icon, label, onPressed) = switch (tab) {
      0 => (
            Icons.add_rounded,
            'Add notice',
            _mutating ? null : _addNotice,
          ),
      1 => (
            Icons.add_rounded,
            'Add resource',
            _mutating ? null : _addResource,
          ),
      2 => (
            Icons.add_rounded,
            'Add exam',
            _mutating ? null : _addExam,
          ),
      _ => (null, '', null),
    };
    if (icon == null) return null;
    return FloatingActionButton.extended(
      onPressed: onPressed as VoidCallback?,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: getIt<SessionController>(),
      builder: (context, _) {
        final canManage = _canManage;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course.code,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: context.colors.textPrimary),
          ),
          floatingActionButton: _buildFab(canManage),
          body: _loading
              ? const _HubSkeletonView()
              : _error != null && _isEmpty
              ? RefreshIndicator(
                  color: context.colors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _loadAll,
                  child: RetryStateList(
                    title: 'Course hub unavailable',
                    message: _error!,
                    onRetry: _loadAll,
                  ),
                )
              : RefreshIndicator(
                  color: context.colors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _loadAll,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      // Freshness + failed-refresh state for the whole hub.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null) ...[
                                DataStateBanner(
                                  message:
                                      'Could not refresh this course. Showing the last loaded data.',
                                  tone: DataStateTone.warning,
                                  onRetry: _loadAll,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: LastUpdatedLabel(
                                  updatedAt: _lastUpdatedAt,
                                  emptyLabel: 'Course not synced yet',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Attendance summary card
                      SliverToBoxAdapter(
                        child: _AttendanceSummaryCard(
                          attendance: _attendance,
                        ),
                      ),
                      // Sticky tab bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyTabBarDelegate(
                          tabBar: TabBar(
                            controller: _tabController,
                            labelColor: context.colors.primary,
                            unselectedLabelColor: context.colors.textMuted,
                            indicatorColor: context.colors.primary,
                            indicatorSize: TabBarIndicatorSize.label,
                            indicatorWeight: 2.5,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.campaign_rounded, size: 16),
                                    const SizedBox(width: 5),
                                    const Text('Notices'),
                                    if (_notices.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      _TabBadge(count: _notices.length),
                                    ],
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_rounded, size: 16),
                                    const SizedBox(width: 5),
                                    const Text('Resources'),
                                    if (_resources.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      _TabBadge(count: _resources.length),
                                    ],
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_calendar_rounded, size: 16),
                                    const SizedBox(width: 5),
                                    const Text('Exams'),
                                    if (_exams.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      _TabBadge(count: _exams.length),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          color: context.colors.surface,
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _NoticesTab(
                          notices: _notices,
                          canManage: canManage,
                          onEdit: _editNotice,
                          onDelete: _deleteNotice,
                        ),
                        _ResourcesTab(
                          resources: _resources,
                          repository: _resourceRepo,
                          canManage: canManage,
                          onEdit: _editResource,
                          onDelete: _deleteResource,
                        ),
                        _ExamsTab(
                          exams: _exams,
                          canManage: canManage,
                          onEdit: _editExam,
                          onDelete: _deleteExam,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Attendance Summary Card
// ═════════════════════════════════════════════════════════════════════════════

class _AttendanceSummaryCard extends StatelessWidget {
  final AttendanceCourseSummary? attendance;

  const _AttendanceSummaryCard({this.attendance});

  @override
  Widget build(BuildContext context) {
    final att = attendance;
    final pct = att?.percentage ?? 0;
    final present = att?.present ?? 0;
    final total = att?.total ?? 0;
    final pctLabel = total == 0 ? '—' : '${(pct * 100).round()}%';
    final statusColor = total == 0
        ? context.colors.textMuted
        : pct >= 0.75
            ? context.colors.success
            : pct >= 0.6
                ? context.colors.warning
                : context.colors.danger;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.12),
            context.colors.surfaceAlt,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: total == 0 ? 0 : pct,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
                Text(
                  pctLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Attendance',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total == 0
                      ? 'No classes recorded yet'
                      : '$present present out of $total ${total == 1 ? 'class' : 'classes'}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            total == 0
                ? Icons.hourglass_empty_rounded
                : pct >= 0.75
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
            color: statusColor,
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _NoticesTab extends StatelessWidget {
  final List<ClassNotice> notices;
  final bool canManage;
  final ValueChanged<ClassNotice> onEdit;
  final ValueChanged<ClassNotice> onDelete;

  const _NoticesTab({
    required this.notices,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (notices.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.campaign_outlined,
          title: 'No class notices yet',
          message: canManage
              ? 'Publish the first notice for this course.'
              : 'Your CR has not posted a notice for this course yet.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      itemCount: notices.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final notice = notices[index];
        return Entrance(
          index: index,
          child: _NoticeCard(
            notice: notice,
            canManage: canManage,
            onEdit: () => onEdit(notice),
            onDelete: () => onDelete(notice),
          ),
        );
      },
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  final List<ResourceItem> resources;
  final ResourceRepository repository;
  final bool canManage;
  final void Function(ResourceItem) onEdit;
  final void Function(ResourceItem) onDelete;

  const _ResourcesTab({
    required this.resources,
    required this.repository,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _open(BuildContext context, ResourceItem resource) async {
    try {
      final target = await repository.resolveResourceUrl(resource);
      if (target.isEmpty) {
        if (context.mounted) showToast(context, 'This resource is no longer available');
        return;
      }
      final uri = Uri.tryParse(target);
      final opened = uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      showToast(context, 'Could not open ${resource.title}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No resources yet',
          message: canManage
              ? 'Share the first file or link for this course.'
              : 'Your CR has not shared a resource for this course yet.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      itemCount: resources.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final resource = resources[index];
        return Entrance(
          index: index,
          child: ResourceCard(
            resource: resource,
            canManage: canManage,
            onOpen: () => _open(context, resource),
            onEdit: () => onEdit(resource),
            onDelete: () => onDelete(resource),
          ),
        );
      },
    );
  }
}

class _ExamsTab extends StatelessWidget {
  final List<ExamItem> exams;
  final bool canManage;
  final void Function(ExamItem) onEdit;
  final void Function(ExamItem) onDelete;

  const _ExamsTab({
    required this.exams,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.edit_calendar_outlined,
          title: 'No exams scheduled',
          message:
              'Your CR has not published any exam notices for this course yet.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        96,
      ),
      itemCount: exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final exam = exams[index];
        return Entrance(
          index: index,
          child: ExamCard(
            exam: exam,
            canManage: canManage,
            onEdit: () => onEdit(exam),
            onDelete: () => onDelete(exam),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ═════════════════════════════════════════════════════════════════════════════

class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: context.colors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;

  const _StickyTabBarDelegate({required this.tabBar, required this.color});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: color,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || color != oldDelegate.color;
}

class _NoticeCard extends StatelessWidget {
  final ClassNotice notice;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoticeCard({
    required this.notice,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  String get _categoryLabel => switch (notice.category) {
        NoticeCategory.academic => 'Academic',
        NoticeCategory.events => 'Event',
        NoticeCategory.department => 'Department',
      };

  @override
  Widget build(BuildContext context) {
    final color = context.colors.resolve(notice.color);
    final body = notice.body.isEmpty ? notice.subtitle : notice.body;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: cardDecoration(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(notice.icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _NoticeChip(label: _categoryLabel, color: color),
                    if (notice.isPinned)
                      _NoticeChip(
                        label: 'Pinned',
                        color: context.colors.warning,
                        icon: Icons.push_pin_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  notice.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  notice.time,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<_NoticeAction>(
              tooltip: 'Notice actions',
              icon: Icon(Icons.more_vert_rounded, color: context.colors.textMuted),
              onSelected: (action) {
                switch (action) {
                  case _NoticeAction.edit:
                    onEdit();
                  case _NoticeAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _NoticeAction.edit,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit notice'),
                  ),
                ),
                PopupMenuItem(
                  value: _NoticeAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: context.colors.danger,
                    ),
                    title: Text(
                      'Delete notice',
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _NoticeAction { edit, delete }

class _NoticeChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _NoticeChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HubSkeletonView extends StatelessWidget {
  const _HubSkeletonView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Attendance skeleton
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: context.colors.border),
          ),
          child: const Row(
            children: [
              Skeleton(
                height: 54,
                width: 54,
                radius: BorderRadius.all(Radius.circular(27)),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 14, width: 140),
                    SizedBox(height: AppSpacing.sm),
                    Skeleton(height: 12, width: 200),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Tab bar skeleton
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Skeleton(height: 12, width: 80),
            Skeleton(height: 12, width: 80),
            Skeleton(height: 12, width: 80),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // Card skeletons
        for (var i = 0; i < 3; i++) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: cardDecoration(context: context),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(
                  height: 42,
                  width: 42,
                  radius: BorderRadius.all(Radius.circular(AppRadii.md)),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(height: 12, width: 75),
                      SizedBox(height: AppSpacing.sm),
                      Skeleton(height: 14, width: 190),
                      SizedBox(height: AppSpacing.sm),
                      Skeleton(height: 12, width: 230),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Notice Editor Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════

typedef _NoticeInput = ({
  String title,
  String body,
  NoticeCategory category,
  bool isPinned,
});

Future<_NoticeInput?> _showNoticeEditor(
  BuildContext context, {
  ClassNotice? notice,
}) {
  return showModalBottomSheet<_NoticeInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NoticeEditorSheet(notice: notice),
  );
}

class _NoticeEditorSheet extends StatefulWidget {
  final ClassNotice? notice;
  const _NoticeEditorSheet({this.notice});

  @override
  State<_NoticeEditorSheet> createState() => _NoticeEditorSheetState();
}

class _NoticeEditorSheetState extends State<_NoticeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late NoticeCategory _category;
  late bool _isPinned;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.notice?.title ?? '');
    _body = TextEditingController(
      text: widget.notice == null
          ? ''
          : widget.notice!.body.isEmpty
              ? widget.notice!.subtitle
              : widget.notice!.body,
    );
    _category = widget.notice?.category ?? NoticeCategory.academic;
    _isPinned = widget.notice?.isPinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      title: _title.text.trim(),
      body: _body.text.trim(),
      category: _category,
      isPinned: _isPinned,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.lg),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.notice == null ? 'Add class notice' : 'Edit class notice',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a notice title'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _body,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the notice details'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<NoticeCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: NoticeCategory.academic,
                        child: Text('Academic'),
                      ),
                      DropdownMenuItem(
                        value: NoticeCategory.events,
                        child: Text('Event'),
                      ),
                      DropdownMenuItem(
                        value: NoticeCategory.department,
                        child: Text('Department'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Pin this notice',
                      style: TextStyle(color: context.colors.textPrimary),
                    ),
                    subtitle: Text(
                      'Pinned notices stay at the top of this course.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _isPinned,
                    onChanged: (value) => setState(() => _isPinned = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: widget.notice == null ? 'Publish notice' : 'Save changes',
                    icon: widget.notice == null
                        ? Icons.campaign_rounded
                        : Icons.check_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
