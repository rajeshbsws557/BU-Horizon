import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../di/di.dart';
import '../models/models.dart';
import '../repositories/attendance_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceCubit(getIt<AttendanceRepository>()),
      child: const _AttendanceView(),
    );
  }
}

class _AttendanceView extends StatefulWidget {
  const _AttendanceView();

  @override
  State<_AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<_AttendanceView> {
  bool _loading = true;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loadingTimer?.cancel();
    final completer = Completer<void>();
    setState(() => _loading = true);
    _loadingTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _loading = false);
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _refresh() => _load();

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AttendanceCubit>().repository;
    final classes = repository.todayClasses;
    final summary = repository.summary();

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance', style: TextStyle(color: context.colors.textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.calendar_today_rounded, size: 20, color: context.colors.textPrimary),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: context.colors.surfaceAlt,
        onRefresh: _refresh,
        semanticsLabel: 'Refresh attendance',
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: context.colors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(DateTime.now()),
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const _AttendanceSkeletonSummary()
            else
              Center(
                child: Semantics(
                  label:
                      'Attendance ${(summary.percentage * 100).round()} percent. ${summary.present} out of ${summary.total} classes present',
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: summary.percentage),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 9,
                                strokeCap: StrokeCap.round,
                                backgroundColor: context.colors.surfaceAlt,
                                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(value * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Present',
                                  style: TextStyle(
                                    color: context.colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${summary.present}/${summary.total} Classes',
                                  style: TextStyle(
                                    color: context.colors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 26),
            Text(
              "Today's Classes",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const _AttendanceSkeletonRows()
            else
              ...List.generate(
                classes.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Entrance(index: i, child: _AttendanceRow(item: classes[i])),
                ),
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'View Attendance History',
              icon: Icons.history_rounded,
              onPressed: () => showToast(context, 'Opening attendance history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSkeletonSummary extends StatelessWidget {
  const _AttendanceSkeletonSummary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.border),
        ),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Skeleton(height: 26, width: 70),
            SizedBox(height: 8),
            Skeleton(height: 13, width: 54),
            SizedBox(height: 6),
            Skeleton(height: 11, width: 72),
          ],
        ),
      ),
    );
  }
}

class _AttendanceSkeletonRows extends StatelessWidget {
  const _AttendanceSkeletonRows();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 130),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 170),
                ],
              ),
            ),
            Skeleton(height: 24, width: 24),
          ],
        ),
      ),
    );
  }
}

class AttendanceCubit extends Cubit<int> {
  AttendanceCubit(this.repository) : super(0);

  final AttendanceRepository repository;

  void refresh() => emit(state);
}

class _AttendanceRow extends StatelessWidget {
  final AttendanceClass item;
  const _AttendanceRow({required this.item});

  @override
  Widget build(BuildContext context) {
    late final Widget trailing;
    late final String statusLabel;
    switch (item.status) {
      case AttendanceStatus.present:
        trailing = Icon(Icons.check_circle_rounded, color: context.colors.success, size: 24);
        statusLabel = 'Present';
        break;
      case AttendanceStatus.absent:
        trailing = Icon(Icons.cancel_rounded, color: context.colors.danger, size: 24);
        statusLabel = 'Absent';
        break;
      case AttendanceStatus.upcoming:
        trailing = Icon(Icons.radio_button_unchecked_rounded, color: context.colors.textMuted, size: 24);
        statusLabel = 'Upcoming';
        break;
    }
    return Semantics(
      label: '${item.subject} at ${item.time}, status $statusLabel',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subject,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.time,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
