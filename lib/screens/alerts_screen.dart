import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/di.dart';
import '../models/models.dart';
import '../repositories/alert_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Rendered as the "Alerts" tab (no back button).
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AlertCubit(getIt<AlertRepository>()),
      child: const _AlertsView(),
    );
  }
}

class _AlertsView extends StatefulWidget {
  const _AlertsView();

  @override
  State<_AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<_AlertsView> {
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
    return SafeArea(
      child: Column(
        children: [
          const TabHeader(title: 'Alerts'),
          const SizedBox(height: 4),
          BlocBuilder<AlertCubit, int>(
            builder: (context, tab) => SegmentedTabs(
              tabs: const ['All', 'Bus', 'Notices', 'Others'],
              selected: tab,
              onChanged: (i) => context.read<AlertCubit>().setTab(i),
            ),
          ),
          Expanded(
            child: BlocBuilder<AlertCubit, int>(
              builder: (context, tab) {
                final repository = context.read<AlertCubit>().repository;
                final visible = switch (tab) {
                  1 => repository.busAlerts(),
                  2 => repository.noticeAlerts(),
                  3 => repository.otherAlerts(),
                  _ => repository.alerts,
                };
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _refresh,
                  semanticsLabel: 'Refresh alerts',
                  child: _loading
                      ? const _AlertSkeletonList()
                      : visible.isEmpty
                          ? const EmptyState(
                              icon: Icons.notifications_off_outlined,
                              title: 'All caught up',
                              message: 'No alerts in this category. You are all clear.',
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  Entrance(index: i, child: _AlertCard(alert: visible[i])),
                            ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertSkeletonList extends StatelessWidget {
  const _AlertSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 42, width: 42, radius: BorderRadius.all(Radius.circular(11))),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 150),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 190),
                ],
              ),
            ),
            SizedBox(width: 8),
            Skeleton(height: 12, width: 54),
          ],
        ),
      ),
    );
  }
}

class AlertCubit extends Cubit<int> {
  AlertCubit(this.repository) : super(0);

  final AlertRepository repository;

  void setTab(int tab) => emit(tab);

  void refresh() => emit(state);
}

class _AlertCard extends StatelessWidget {
  final AlertItem alert;
  const _AlertCard({required this.alert});

  static (IconData, Color) _style(BuildContext context, AlertType t) {
    switch (t) {
      case AlertType.bus:
        return (Icons.directions_bus_rounded, context.colors.warning);
      case AlertType.notice:
        return (Icons.campaign_rounded, AppColors.primary);
      case AlertType.exam:
        return (Icons.edit_document, context.colors.accentCyan);
      case AlertType.event:
        return (Icons.celebration_rounded, context.colors.danger);
      case AlertType.library:
        return (Icons.local_library_rounded, context.colors.purple);
      case AlertType.lostFound:
        return (Icons.inventory_2_rounded, context.colors.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style(context, alert.type);
    return Semantics(
      label: '${alert.type.name} alert. ${alert.title}. ${alert.subtitle}. ${alert.time}',
      child: Container(
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    alert.subtitle,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              alert.time,
              style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
