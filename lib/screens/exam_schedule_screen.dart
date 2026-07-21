import 'package:flutter/material.dart';

import '../di/di.dart';
import '../models/models.dart';
import '../repositories/exam_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

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

  @override
  Widget build(BuildContext context) {
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
            : _exams.isEmpty
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
                    itemCount: _exams.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        Entrance(index: i, child: _ExamCard(exam: _exams[i])),
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

class _ExamCard extends StatelessWidget {
  final ExamItem exam;
  const _ExamCard({required this.exam});

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
