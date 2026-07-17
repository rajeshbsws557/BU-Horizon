import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/blood_bloc.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../repositories/blood_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class BloodHelpScreen extends StatelessWidget {
  const BloodHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BloodBloc(getIt<BloodRepository>())..add(const BloodTabChanged(0)),
      child: const _BloodHelpView(),
    );
  }
}

class _BloodHelpView extends StatefulWidget {
  const _BloodHelpView();

  @override
  State<_BloodHelpView> createState() => _BloodHelpViewState();
}

class _BloodHelpViewState extends State<_BloodHelpView> {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Blood Help', style: TextStyle(color: context.colors.textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: Column(
        children: [
          BlocBuilder<BloodBloc, BloodState>(
            buildWhen: (previous, current) => previous.tab != current.tab,
            builder: (context, state) => SegmentedTabs(
              tabs: const ['Request Blood', 'Donate Blood'],
              selected: state.tab,
              onChanged: (i) => context.read<BloodBloc>().add(BloodTabChanged(i)),
            ),
          ),
          Expanded(
            child: BlocBuilder<BloodBloc, BloodState>(
              builder: (context, state) {
                final need = state.urgentNeed;
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _refresh,
                  semanticsLabel: 'Refresh blood requests',
                  child: _loading
                      ? const _BloodSkeletonList()
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            Semantics(
                              label:
                                  'Urgent blood need. ${need.units} units of ${need.group.label} blood. Contact ${need.contact} at ${need.location}. Posted ${need.time}',
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: AppColors.bloodGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.danger.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.water_drop_rounded, color: Colors.white, size: 30),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Need Blood',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.95),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${need.units} Units (${need.group.label})',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Contact: ${need.contact}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          Text(
                                            'Location: ${need.location}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      need.time,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Recent Requests',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(
                              state.requests.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Entrance(
                                  index: i,
                                  child: _RequestRow(request: state.requests[i]),
                                ),
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BlocBuilder<BloodBloc, BloodState>(
              buildWhen: (previous, current) => previous.tab != current.tab,
              builder: (context, state) => PrimaryButton(
                label: state.tab == 0 ? 'Request Blood' : 'Register as Donor',
                icon: Icons.water_drop_rounded,
                onPressed: () => showToast(
                  context,
                  state.tab == 0 ? 'Blood request posted' : 'Registered as donor',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BloodSkeletonList extends StatelessWidget {
  const _BloodSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: const Row(
            children: [
              Skeleton(height: 30, width: 30, radius: BorderRadius.all(Radius.circular(15))),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 16, width: 120),
                    SizedBox(height: 8),
                    Skeleton(height: 12, width: 180),
                    SizedBox(height: 6),
                    Skeleton(height: 12, width: 160),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Skeleton(height: 15, width: 120),
        const SizedBox(height: 12),
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: const Row(
                children: [
                  Skeleton(height: 42, width: 42, radius: BorderRadius.all(Radius.circular(11))),
                  SizedBox(width: 12),
                  Expanded(child: Skeleton(height: 14, width: 140)),
                  SizedBox(width: 12),
                  Skeleton(height: 12, width: 50),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  final BloodRequest request;
  const _RequestRow({required this.request});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Blood request ${request.group.label} at ${request.location}, ${request.time}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.colors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                request.group.label,
                style: TextStyle(
                  color: context.colors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                request.location,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            Text(
              request.time,
              style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
