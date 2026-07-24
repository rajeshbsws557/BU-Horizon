import 'package:flutter/material.dart';

import '../di/di.dart';
import '../models/models.dart';
import '../repositories/exam_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/term_selector.dart';

/// The signed-in student's batch exam schedule (quizzes, midterms, finals).
/// RLS scopes the query to the student's own batch.
class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  bool _loading = true;
  List<ExamItem> _exams = const [];
  int? _selectedTerm;

  bool get _canManage =>
      getIt<SessionController>().profile?.role.toLowerCase() == 'cr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final exams = await getIt<ExamRepository>().fetchExams();
      if (!mounted) return;
      setState(() {
        _exams = exams;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Could not load the exam schedule');
    }
  }

  Future<void> _editExam(ExamItem exam) async {
    final input = await showExamEditorSheet(context, exam: exam);
    if (input == null || !mounted) return;
    try {
      await getIt<ExamRepository>().updateExam(examId: exam.id, input: input);
      if (!mounted) return;
      showToast(context, 'Exam updated');
      _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not update exam');
    }
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
    try {
      await getIt<ExamRepository>().deleteExam(exam.id);
      if (!mounted) return;
      showToast(context, 'Exam deleted');
      _load();
    } catch (_) {
      if (mounted) showToast(context, 'Could not delete exam');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManage;
    
    final availableTerms = _exams.map((e) => e.termNumber ?? 1).toSet().toList()..sort();
    if (_selectedTerm == null || !availableTerms.contains(_selectedTerm)) {
      _selectedTerm = getIt<SessionController>().profile?.currentTerm;
    }
    if ((_selectedTerm == null || !availableTerms.contains(_selectedTerm)) && availableTerms.isNotEmpty) {
      _selectedTerm = availableTerms.last;
    }
    
    final filteredExams = _exams.where((e) => (e.termNumber ?? 1) == _selectedTerm).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Schedule',
            style: TextStyle(color: context.colors.textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: RefreshIndicator(
        color: context.colors.primary,
        backgroundColor: context.colors.surfaceAlt,
        onRefresh: _load,
        semanticsLabel: 'Refresh exam schedule',
        child: _loading
            ? const _ExamSkeletonList()
            : filteredExams.isEmpty && _exams.isNotEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16).copyWith(bottom: 0),
                        child: TermSelector(
                          terms: availableTerms,
                          selectedTerm: _selectedTerm,
                          onSelected: (term) => setState(() => _selectedTerm = term),
                        ),
                      ),
                      const SizedBox(height: 120),
                      const EmptyState(
                        icon: Icons.edit_calendar_outlined,
                        title: 'No exams this term',
                        message: 'Your CR has not published any exam notices for this term yet.',
                      ),
                    ],
                  )
                : filteredExams.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                        icon: Icons.edit_calendar_outlined,
                        title: 'No exams scheduled',
                        message:
                            'Your CR has not published any exam notices yet.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredExams.length + 1,
                    separatorBuilder: (_, index) => index == 0 ? const SizedBox.shrink() : const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        return availableTerms.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: TermSelector(
                                terms: availableTerms,
                                selectedTerm: _selectedTerm,
                                onSelected: (term) => setState(() => _selectedTerm = term),
                              ),
                            )
                          : const SizedBox.shrink();
                      }
                      
                      final i = index - 1;
                      return Entrance(
                        index: i,
                        child: ExamCard(
                          exam: filteredExams[i],
                          canManage: canManage,
                          onEdit: () => _editExam(filteredExams[i]),
                          onDelete: () => _deleteExam(filteredExams[i]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ExamSkeletonList extends StatelessWidget {
  const _ExamSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 14, width: 180),
            SizedBox(height: 8),
            Skeleton(height: 12, width: 220),
            SizedBox(height: 8),
            Skeleton(height: 12, width: 140),
          ],
        ),
      ),
    );
  }
}

class ExamCard extends StatelessWidget {
  final ExamItem exam;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExamCard({
    super.key,
    required this.exam,
    this.canManage = false,
    this.onEdit,
    this.onDelete,
  });

  Color _accent(BuildContext context) => switch (exam.typeLabel) {
        'Final' => context.colors.danger,
        'Midterm' => context.colors.warning,
        _ => context.colors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Semantics(
      label:
          '${exam.typeLabel}. ${exam.title}. ${exam.dateLabel} ${exam.timeLabel}.'
          '${exam.room.isNotEmpty ? ' Room ${exam.room}.' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    exam.typeLabel,
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (exam.courseCode.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    exam.courseCode,
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  exam.dateLabel,
                  style:
                      TextStyle(color: context.colors.textMuted, fontSize: 11.5),
                ),
                if (canManage && onEdit != null && onDelete != null) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<_ExamAction>(
                    tooltip: 'Exam actions',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: context.colors.textMuted,
                      size: 18,
                    ),
                    onSelected: (action) {
                      switch (action) {
                        case _ExamAction.edit:
                          onEdit!();
                        case _ExamAction.delete:
                          onDelete!();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _ExamAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit exam'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _ExamAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: context.colors.danger,
                          ),
                          title: Text(
                            'Delete exam',
                            style: TextStyle(color: context.colors.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              exam.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
                color: context.colors.textPrimary,
              ),
            ),
            if (exam.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                exam.description,
                style:
                    TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 14, color: context.colors.textMuted),
                const SizedBox(width: 4),
                Text(
                  exam.timeLabel,
                  style:
                      TextStyle(color: context.colors.textMuted, fontSize: 12),
                ),
                if (exam.room.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.place_outlined,
                      size: 14, color: context.colors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    'Room ${exam.room}',
                    style: TextStyle(
                        color: context.colors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExamAction { edit, delete }

Future<ExamInput?> showExamEditorSheet(
  BuildContext context, {
  ExamItem? exam,
}) {
  return showModalBottomSheet<ExamInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExamEditorSheet(exam: exam),
  );
}

class _ExamEditorSheet extends StatefulWidget {
  final ExamItem? exam;
  const _ExamEditorSheet({this.exam});

  @override
  State<_ExamEditorSheet> createState() => _ExamEditorSheetState();
}

class _ExamEditorSheetState extends State<_ExamEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _room;
  late final TextEditingController _description;
  late String _type;
  DateTime? _examDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.exam?.title ?? '');
    _room = TextEditingController(text: widget.exam?.room ?? '');
    _description = TextEditingController(text: widget.exam?.description ?? '');
    _type = widget.exam?.typeLabel.toLowerCase() == 'midterm'
        ? 'midterm'
        : widget.exam?.typeLabel.toLowerCase() == 'final'
            ? 'final'
            : widget.exam?.typeLabel.toLowerCase() == 'quiz'
                ? 'quiz'
                : 'other';
  }

  @override
  void dispose() {
    _title.dispose();
    _room.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() => _examDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime ?? TimeOfDay.now()),
    );
    if (picked != null && mounted) {
      setState(() => _endTime = picked);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      title: _title.text.trim(),
      type: _type,
      examDate: _examDate,
      startTime: _startTime,
      endTime: _endTime,
      room: _room.text.trim().isEmpty ? null : _room.text.trim(),
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
    ));
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    widget.exam == null ? 'New Exam Notice' : 'Edit Exam Notice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Exam Type',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                      DropdownMenuItem(value: 'midterm', child: Text('Midterm')),
                      DropdownMenuItem(value: 'final', child: Text('Final')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? 'other'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Title (e.g. Quiz 1 — Chapters 1-3)',
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Enter exam title' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_rounded, size: 16),
                          label: Text(
                            _examDate != null
                                ? '${_examDate!.month}/${_examDate!.day}/${_examDate!.year}'
                                : 'Pick Date',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _room,
                          decoration: const InputDecoration(
                            labelText: 'Room (optional)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickStartTime,
                          icon: const Icon(Icons.access_time_rounded, size: 16),
                          label: Text(
                            _startTime != null
                                ? _startTime!.format(context)
                                : 'Start Time',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickEndTime,
                          icon: const Icon(Icons.access_time_rounded, size: 16),
                          label: Text(
                            _endTime != null
                                ? _endTime!.format(context)
                                : 'End Time',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description / Syllabus (optional)',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(widget.exam == null ? 'Publish' : 'Save'),
                      ),
                    ],
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
