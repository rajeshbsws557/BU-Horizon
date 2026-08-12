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

/// Campus directory search, pushed as a sub-page (so it owns a back button).
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
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  /// Department chip filter applied on top of the text query. `null` = All.
  String? _department;

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

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    context.read<PeopleBloc>().add(const PeopleSearched(''));
  }

  /// Distinct departments across the loaded directory, for the chip row.
  List<String> _departments(List<Person> people) {
    final set = <String>{for (final p in people) p.department};
    final list = set.toList()..sort();
    return list;
  }

  /// The chip filter is a pure client-side narrowing of the bloc's results.
  List<Person> _applyFilter(List<Person> people) {
    if (_department == null) return people;
    return people.where((p) => p.department == _department).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
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
    return Scaffold(
      // A real AppBar gives this pushed page the standard back button, so the
      // system back gesture and the arrow both return to where you came from.
      appBar: AppBar(
        title: const Text('People Search'),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: ResponsivePage(
        child: BlocBuilder<PeopleBloc, PeopleState>(
          builder: (context, state) {
            final departments = _departments(state.people);
            final visible = _applyFilter(state.people);
            return Column(
              children: [
                _SearchBar(
                  controller: _controller,
                  onChanged: _onSearchChanged,
                  onClear: _clear,
                ),
                _DepartmentFilter(
                  departments: departments,
                  selected: _department,
                  onSelected: (d) => setState(() => _department = d),
                ),
                _ResultCount(
                  count: visible.length,
                  isLoading: state.isLoading,
                ),
                Expanded(
                  child: _Results(
                    people: visible,
                    isLoading: state.isLoading,
                    colors: avatarColors,
                    onMail: _mailTo,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


/// Pill search input with a live clear button.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.border),
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Search name, department or email',
              hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: colors.textMuted, size: 21),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClear,
                      tooltip: 'Clear search',
                      icon: Icon(Icons.close_rounded,
                          color: colors.textMuted, size: 19),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal department chips. Departments are labelled "X Department" in the
/// data, so the chip trims that suffix to keep the row short and readable.
class _DepartmentFilter extends StatelessWidget {
  final List<String> departments;
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _DepartmentFilter({
    required this.departments,
    required this.selected,
    required this.onSelected,
  });

  static String _short(String department) =>
      department.replaceAll(RegExp(r'\s*Department$'), '');

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: 'All',
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final d in departments)
            _Chip(
              label: _short(d),
              selected: selected == d,
              onTap: () => onSelected(selected == d ? null : d),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: 0.14)
              : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? colors.primary : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet "N people" caption so the result set size is always obvious.
class _ResultCount extends StatelessWidget {
  final int count;
  final bool isLoading;
  const _ResultCount({required this.count, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          isLoading
              ? 'Searching…'
              : '$count ${count == 1 ? 'person' : 'people'} found',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: context.colors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Loading / empty / list switch for the directory results.
class _Results extends StatelessWidget {
  final List<Person> people;
  final bool isLoading;
  final List<Color> colors;
  final Future<void> Function(String email) onMail;
  const _Results({
    required this.people,
    required this.isLoading,
    required this.colors,
    required this.onMail,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _PeopleSkeletonList();
    if (people.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_outlined,
        title: 'No one found',
        message: 'No students or staff match your search. '
            'Try another name or department.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: people.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = people[i];
        return Entrance(
          // Re-key on identity so filtering replays the entrance animation
          // instead of reusing the previous row's finished state.
          key: ValueKey('person-${p.email}'),
          index: i,
          stagger: const Duration(milliseconds: 35),
          child: _PersonCard(
            person: p,
            color: colors[i % colors.length],
            onMail: () => onMail(p.email),
          ),
        );
      },
    );
  }
}

/// Placeholder rows mirroring [_PersonCard]'s metrics, so the list doesn't
/// jump when real results arrive.
class _PeopleSkeletonList extends StatelessWidget {
  const _PeopleSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: context.colors.border),
        ),
        child: const Row(
          children: [
            Skeleton(
              height: 48,
              width: 48,
              radius: BorderRadius.all(Radius.circular(24)),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 140),
                  SizedBox(height: 7),
                  Skeleton(height: 16, width: 96, radius: BorderRadius.all(Radius.circular(6))),
                  SizedBox(height: 7),
                  Skeleton(height: 11, width: 170),
                ],
              ),
            ),
            SizedBox(width: 8),
            Skeleton(
              height: 42,
              width: 42,
              radius: BorderRadius.all(Radius.circular(12)),
            ),
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
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // Exclude only the informational part so the mail button beside it
          // stays reachable by screen readers.
          Expanded(
            child: Semantics(
              label: '${person.name}, ${person.department}, ${person.email}',
              excludeSemantics: true,
              child: Row(
                children: [
                  // Gradient ring avatar — reads as a person, not a grey blob.
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.28),
                          color.withValues(alpha: 0.10),
                        ],
                      ),
                      border: Border.all(
                        color: color.withValues(alpha: 0.40),
                      ),
                    ),
                    child: Text(
                      person.initials,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Department as a tinted badge so it scans instantly.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            person.department,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.alternate_email_rounded,
                                size: 12, color: colors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                person.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filled tonal button reads as the card's primary action, unlike the
          // previous bare icon which looked like decoration.
          Semantics(
            button: true,
            label: 'Email ${person.name}',
            child: Tooltip(
              message: 'Email ${person.name}',
              child: Material(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onMail,
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

