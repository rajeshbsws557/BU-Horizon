import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/people_bloc.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../repositories/people_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Rendered as the "Search" tab (no back button).
class PeopleSearchScreen extends StatelessWidget {
  const PeopleSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PeopleBloc(getIt<PeopleRepository>())..add(const PeopleSearched('')),
      child: const _PeopleSearchView(),
    );
  }
}

class _PeopleSearchView extends StatefulWidget {
  const _PeopleSearchView();

  @override
  State<_PeopleSearchView> createState() => _PeopleSearchViewState();
}

class _PeopleSearchViewState extends State<_PeopleSearchView> {
  Timer? _debounce;

  Future<void> _mailTo(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      showToast(context, 'Could not open mail app for $email');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<PeopleBloc>().add(PeopleSearched(value));
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarColors = [
      context.colors.primary,
      context.colors.accentCyan,
      context.colors.purple,
      context.colors.warning,
      context.colors.success,
      context.colors.danger,
    ];
    return SafeArea(
      child: ResponsivePage(
        child: Column(
          children: [
            const TabHeader(title: 'People Search'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SearchField(
                hint: 'Search by name or department',
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: BlocBuilder<PeopleBloc, PeopleState>(
                builder: (context, state) {
                  final visible = state.people;
                  return state.isLoading
                      ? const _PeopleSkeletonList()
                      : visible.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No one found',
                          message:
                              'No students or staff match your search. Try another name or department.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = visible[i];
                            return Entrance(
                              index: i,
                              stagger: const Duration(milliseconds: 40),
                              child: _PersonCard(
                                person: p,
                                color: avatarColors[i % avatarColors.length],
                                onMail: () => _mailTo(p.email),
                              ),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleSkeletonList extends StatelessWidget {
  const _PeopleSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: const Row(
          children: [
            Skeleton(
              height: 44,
              width: 44,
              radius: BorderRadius.all(Radius.circular(22)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 140),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 180),
                  SizedBox(height: 6),
                  Skeleton(height: 12, width: 150),
                ],
              ),
            ),
            SizedBox(width: 8),
            Skeleton(height: 20, width: 20),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final Person person;
  final Color color;
  final VoidCallback onMail;
  const _PersonCard({
    required this.person,
    required this.color,
    required this.onMail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          // Exclude only the informational part so the mail button below
          // stays reachable by screen readers.
          Expanded(
            child: Semantics(
              label: '${person.name}, ${person.department}, ${person.email}',
              excludeSemantics: true,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: color.withValues(alpha: 0.18),
                    child: Text(
                      person.initials,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          person.department,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          person.email,
                          style: TextStyle(
                            color: context.colors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onMail,
            tooltip: 'Email ${person.name}',
            icon: Icon(
              Icons.mail_outline_rounded,
              color: context.colors.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
