import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../di/di.dart';
import '../models/course_offering.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'motion.dart';
import 'term_history_sheet.dart';


/// Shared course-first list used by class notices, resources and attendance.
class CourseCatalogView extends StatefulWidget {
  final bool isLoading;
  final bool canManage;
  final List<CourseOffering> courses;
  final String featureName;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  final ValueChanged<CourseOffering> onOpen;
  final ValueChanged<CourseOffering>? onEdit;
  final ValueChanged<CourseOffering>? onDelete;

  /// Controlled term selection. When [selectedTerm]/[onTermSelected] are
  /// provided, the parent owns the selected term (e.g. it renders the semester
  /// history button in its AppBar) and the view hides its own inline history
  /// icon. Otherwise the view manages term selection internally.
  final int? selectedTerm;
  final ValueChanged<int>? onTermSelected;

  const CourseCatalogView({
    super.key,
    required this.isLoading,
    required this.canManage,
    required this.courses,
    required this.featureName,
    required this.emptyIcon,
    required this.onRefresh,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
    this.selectedTerm,
    this.onTermSelected,
  });

  /// Terms a student can browse: the full range the batch has reached
  /// (1..currentTerm) merged with any term that actually has courses. Shared so
  /// a parent that owns term selection builds the exact same range.
  static List<int> availableTermsFor({
    required List<CourseOffering> courses,
    required int? currentTerm,
  }) {
    final contentTerms = courses.map((c) => c.termNumber ?? 1).toSet();
    final maxTerm = [
      if (currentTerm != null) currentTerm,
      ...contentTerms,
    ].fold(0, (a, b) => a > b ? a : b);
    return maxTerm == 0
        ? (contentTerms.toList()..sort())
        : List.generate(maxTerm, (i) => i + 1);
  }


  @override
  State<CourseCatalogView> createState() => _CourseCatalogViewState();
}

class _CourseCatalogViewState extends State<CourseCatalogView> {
  int? _internalTerm;

  /// True when the parent owns term selection (and renders the history button
  /// itself, e.g. in the AppBar next to the "+").
  bool get _controlled => widget.onTermSelected != null;

  int? get _selectedTerm =>
      _controlled ? widget.selectedTerm : _internalTerm;

  void _selectTerm(int term) {
    if (_controlled) {
      widget.onTermSelected!(term);
    } else {
      setState(() => _internalTerm = term);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = getIt<SessionController>().profile;
    final termLabel = profile?.termLabel ?? 'Semester';
    final currentTerm = profile?.currentTerm;
    // Browsable terms span the full range the batch has reached (1..current)
    // merged with any term that has courses — not just terms that have content.
    // Otherwise a freshly-advanced term (with no courses yet) or an empty past
    // term could never be selected.
    final availableTerms = CourseCatalogView.availableTermsFor(
      courses: widget.courses,
      currentTerm: currentTerm,
    );
    // Only initialize the internal selection once (or when it falls out of
    // range). Never overwrite a term the student deliberately picked. When the
    // parent controls selection this is skipped entirely.
    if (!_controlled &&
        (_internalTerm == null || !availableTerms.contains(_internalTerm))) {
      _internalTerm = currentTerm != null && availableTerms.contains(currentTerm)
          ? currentTerm
          : (availableTerms.isNotEmpty ? availableTerms.last : null);
    }

    final filteredCourses = widget.courses.where((c) => (c.termNumber ?? 1) == _selectedTerm).toList();



    return RefreshIndicator(
      color: context.colors.primary,
      backgroundColor: context.colors.surfaceAlt,
      onRefresh: widget.onRefresh,
      semanticsLabel: 'Refresh courses',
      child: widget.isLoading
          ? const _CourseSkeletonList()
          : filteredCourses.isEmpty && widget.courses.isNotEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),

                    EmptyState(
                      icon: widget.emptyIcon,
                      title: 'No courses this term',
                      message: widget.canManage
                          ? 'Add a course for this term to start sharing ${widget.featureName}.'
                          : 'Your CR has not added any courses for this term yet.',
                    ),
                  ],
                )
              : filteredCourses.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    EmptyState(
                      icon: widget.emptyIcon,
                      title: 'No courses yet',
                      message: widget.canManage
                          ? 'Add your batch courses to start sharing ${widget.featureName}.'
                          : 'Your CR has not added any courses for this batch yet.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filteredCourses.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The semester slider was removed by design: the app
                          // shows the current term by default and students jump
                          // to previous terms through the "View history" button.
                          // When the parent owns term selection it renders that
                          // button in its AppBar; otherwise we surface a small
                          // inline one here so history stays reachable.
                          if (!_controlled &&
                              availableTerms.isNotEmpty &&
                              _selectedTerm != null) ...[
                            _TermHistoryBar(
                              termLabel: termLabel,
                              selectedTerm: _selectedTerm!,
                              isCurrent: _selectedTerm == currentTerm,
                              onTap: () async {
                                final picked = await showTermHistorySheet(
                                  context,
                                  availableTerms: availableTerms,
                                  selectedTerm: _selectedTerm,
                                  currentTerm: profile?.currentTerm,
                                  termLabel: termLabel,
                                );
                                if (picked != null && mounted) {
                                  _selectTerm(picked);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                          ],


                          _CatalogIntro(
                            count: filteredCourses.length,
                            featureName: widget.featureName,
                          ),
                        ],
                      );
                    }

                    final course = filteredCourses[index - 1];
                    return Entrance(
                      index: index - 1,
                      child: _CourseCard(
                        course: course,
                        canManage: widget.canManage,
                        onOpen: () => widget.onOpen(course),
                        onEdit: widget.onEdit == null ? null : () => widget.onEdit!(course),
                        onDelete:
                            widget.onDelete == null ? null : () => widget.onDelete!(course),
                      ),
                    );
                  },
                ),
    );
  }
}

class _CatalogIntro extends StatelessWidget {
  final int count;
  final String featureName;

  const _CatalogIntro({required this.count, required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: context.colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'course' : 'courses'} in your batch',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose a course to view its $featureName.',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12.5,
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

/// A compact "viewing <Term>" pill that opens the semester history sheet.
/// This replaces the old inline semester slider: the current term shows by
/// default and previous terms are reached through history.
class _TermHistoryBar extends StatelessWidget {
  final String termLabel;
  final int selectedTerm;
  final bool isCurrent;
  final VoidCallback onTap;

  const _TermHistoryBar({
    required this.termLabel,
    required this.selectedTerm,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 18,
                color: context.colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Viewing ',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: '$termLabel $selectedTerm',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isCurrent)
                        TextSpan(
                          text: '  •  Current',
                          style: TextStyle(
                            color: context.colors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Text(
                'Change',
                style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.colors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseOffering course;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CourseCard({
    required this.course,
    required this.canManage,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${course.code}, ${course.title}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: cardDecoration(context: context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: context.colors.blueGradient,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            course.code,
                            style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (course.termNumber != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          _MetaChip(label: 'Term ${course.termNumber}'),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      course.title,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        height: 1.25,
                      ),
                    ),
                    if (course.teacherName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: context.colors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              course.teacherName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (canManage && (onEdit != null || onDelete != null))
                PopupMenuButton<_CourseAction>(
                  tooltip: 'Course actions',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: context.colors.textMuted,
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _CourseAction.edit:
                        onEdit?.call();
                      case _CourseAction.delete:
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: _CourseAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit course'),
                        ),
                      ),
                    if (onDelete != null)
                      PopupMenuItem(
                        value: _CourseAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: context.colors.danger,
                          ),
                          title: Text(
                            'Delete course',
                            style: TextStyle(color: context.colors.danger),
                          ),
                        ),
                      ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CourseAction { edit, delete }

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CourseSkeletonList extends StatelessWidget {
  const _CourseSkeletonList();

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
          children: [
            Skeleton(
              height: 48,
              width: 48,
              radius: BorderRadius.all(Radius.circular(AppRadii.md)),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 13, width: 90),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(height: 14, width: 220),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(height: 11, width: 150),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collects fields for a new or existing course. Persistence stays with the
/// caller so all feature screens share identical validation and presentation.
Future<CourseInput?> showCourseEditorSheet(
  BuildContext context, {
  CourseOffering? course,
}) {
  return showModalBottomSheet<CourseInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CourseEditorSheet(course: course),
  );
}

class _CourseEditorSheet extends StatefulWidget {
  final CourseOffering? course;
  const _CourseEditorSheet({this.course});

  @override
  State<_CourseEditorSheet> createState() => _CourseEditorSheetState();
}

class _CourseEditorSheetState extends State<_CourseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _credits;
  late final TextEditingController _term;
  late final TextEditingController _teacher;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _code = TextEditingController(text: course?.code ?? '');
    _title = TextEditingController(text: course?.title ?? '');
    _credits = TextEditingController(
      text: course?.creditHours?.toString().replaceFirst(RegExp(r'\.0$'), '') ?? '',
    );
    // New courses default to the CR's current term so they never silently land
    // in the 1st semester; editing keeps the course's own term.
    final defaultTerm = course?.termNumber ??
        (course == null
            ? getIt<SessionController>().profile?.currentTerm
            : null);
    _term = TextEditingController(text: defaultTerm?.toString() ?? '');
    _teacher = TextEditingController(text: course?.teacherName ?? '');
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _credits.dispose();
    _term.dispose();
    _teacher.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CourseInput(
        code: _code.text.trim().toUpperCase(),
        title: _title.text.trim(),
        creditHours: _credits.text.trim().isEmpty
            ? null
            : double.parse(_credits.text.trim()),
        termNumber: _term.text.trim().isEmpty
            ? null
            : int.parse(_term.text.trim()),
        teacherName: _teacher.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
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
                    widget.course == null ? 'Add course' : 'Edit course',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This course will be available to every student in your batch.',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Course code',
                      hintText: 'CSE-2101',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the course code'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Course title',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the course title'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _credits,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d{0,2}(\.\d?)?$'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Credits',
                            hintText: '3.0',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return null;
                            final parsed = double.tryParse(value.trim());
                            return parsed == null || parsed < 0
                                ? 'Invalid credits'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: _term,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Term',
                            hintText: '1',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return null;
                            final parsed = int.tryParse(value.trim());
                            return parsed == null || parsed < 1
                                ? 'Invalid term'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _teacher,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Teacher (optional)',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: widget.course == null ? 'Add course' : 'Save changes',
                    icon: widget.course == null
                        ? Icons.add_rounded
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
