import 'package:flutter/material.dart';

import '../di/di.dart';
import '../models/course_offering.dart';
import '../models/models.dart';
import '../repositories/course_repository.dart';
import '../repositories/notice_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/course_catalog.dart';
import '../widgets/motion.dart';

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

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    if (mounted) setState(() => _loading = true);
    try {
      final courses = await _coursesRepository.fetchCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Could not load your batch courses');
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
        builder: (_) => _CourseNoticesScreen(course: course),
      ),
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
            title: Text(
              'Class Notices',
              style: TextStyle(color: context.colors.textPrimary),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: context.colors.textPrimary),
            actions: [
              if (canManage)
                IconButton(
                  onPressed: _mutating ? null : _addCourse,
                  tooltip: 'Add course',
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
          body: CourseCatalogView(
            isLoading: _loading,
            canManage: canManage,
            courses: _courses,
            featureName: 'class notices',
            emptyIcon: Icons.campaign_outlined,
            onRefresh: _loadCourses,
            onOpen: _openCourse,
            onEdit: canManage ? _editCourse : null,
            onDelete: canManage ? _deleteCourse : null,
          ),
        );
      },
    );
  }
}

class _CourseNoticesScreen extends StatefulWidget {
  final CourseOffering course;

  const _CourseNoticesScreen({required this.course});

  @override
  State<_CourseNoticesScreen> createState() => _CourseNoticesScreenState();
}

class _CourseNoticesScreenState extends State<_CourseNoticesScreen> {
  late final NoticeRepository _repository = getIt<NoticeRepository>();
  bool _loading = true;
  bool _mutating = false;
  List<ClassNotice> _notices = const [];

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final notices = await _repository.fetchCourseNotices(widget.course.id);
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Could not load class notices');
    }
  }

  Future<void> _addNotice() async {
    final input = await _showNoticeEditor(context);
    if (input == null || !mounted) return;
    await _runMutation(
      () => _repository.createCourseNotice(
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
      () => _repository.updateCourseNotice(
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
        content: Text('“${notice.title}” will no longer be visible to students.'),
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
      () => _repository.deleteCourseNotice(notice.id),
      successMessage: 'Class notice deleted',
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
      await _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not save that change');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
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
                  'Class notices',
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
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  onPressed: _mutating ? null : _addNotice,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add notice'),
                )
              : null,
          body: RefreshIndicator(
            color: context.colors.primary,
            backgroundColor: context.colors.surfaceAlt,
            onRefresh: _load,
            child: _loading
                ? const _NoticeSkeletonList()
                : _notices.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _CourseHeader(course: widget.course),
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.48,
                            child: EmptyState(
                              icon: Icons.campaign_outlined,
                              title: 'No class notices yet',
                              message: canManage
                                  ? 'Publish the first notice for this course.'
                                  : 'Your CR has not posted a notice for this course yet.',
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          96,
                        ),
                        itemCount: _notices.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _CourseHeader(course: widget.course);
                          }
                          final notice = _notices[index - 1];
                          return Entrance(
                            index: index - 1,
                            child: _NoticeCard(
                              notice: notice,
                              canManage: canManage,
                              onEdit: () => _editNotice(notice),
                              onDelete: () => _deleteNotice(notice),
                            ),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final CourseOffering course;
  const _CourseHeader({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.18),
            context.colors.accentCyan.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.code,
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  course.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

class _NoticeSkeletonList extends StatelessWidget {
  const _NoticeSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Container(
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
    );
  }
}

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
