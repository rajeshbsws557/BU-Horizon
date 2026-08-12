// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/home_cards_cubit.dart';
import '../data/home_cards.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Opens the "Customize your home" editor.
///
/// Students pick which quick cards appear on the home screen, drag them into
/// the order they want, and can always fall back to the two defaults. Changes
/// apply live behind the sheet — there is no Save button to forget.
Future<void> showHomeCardsCustomizer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _HomeCardsCustomizerSheet(),
  );
}

class _HomeCardsCustomizerSheet extends StatelessWidget {
  const _HomeCardsCustomizerSheet();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: context.colors.border),
          ),
          child: BlocBuilder<HomeCardsCubit, List<HomeCard>>(
            builder: (context, pinned) {
              final cubit = context.read<HomeCardsCubit>();
              final available = cubit.availableCards;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                    child: _Header(
                      onReset: () {
                        HapticFeedback.selectionClick();
                        cubit.resetToDefaults();
                        showToast(context, 'Home cards reset to default');
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        _SectionLabel(
                          icon: Icons.dashboard_customize_rounded,
                          title: 'On your home screen',
                          trailing: '${pinned.length}/${HomeCardCatalog.maxCards}',
                        ),
                        const SizedBox(height: 10),
                        if (pinned.isEmpty)
                          const _EmptyPinnedHint()
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            buildDefaultDragHandles: false,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pinned.length,
                            onReorder: cubit.reorder,
                            proxyDecorator: (child, index, animation) =>
                                Material(
                              color: Colors.transparent,
                              child: child,
                            ),
                            itemBuilder: (context, index) {
                              final card = pinned[index];
                              return _PinnedRow(
                                key: ValueKey('pinned-${card.id}'),
                                card: card,
                                index: index,
                                onRemove: () {
                                  HapticFeedback.selectionClick();
                                  cubit.remove(card.id);
                                },
                              );
                            },
                          ),
                        const SizedBox(height: 22),
                        _SectionLabel(
                          icon: Icons.add_circle_outline_rounded,
                          title: 'Add more cards',
                          trailing: available.isEmpty ? 'All added' : null,
                        ),
                        const SizedBox(height: 10),
                        if (available.isEmpty)
                          Text(
                            'Every available card is already on your home '
                            'screen.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.colors.textMuted,
                            ),
                          )
                        else ...[
                          if (cubit.isAtMax)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'You have reached the ${HomeCardCatalog.maxCards}-card '
                                'limit. Remove one to add another.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: context.colors.warning,
                                ),
                              ),
                            ),
                          for (final card in available) ...[
                            _AvailableRow(
                              card: card,
                              disabled: cubit.isAtMax,
                              onAdd: () {
                                HapticFeedback.selectionClick();
                                cubit.add(card.id);
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 12),
          decoration: BoxDecoration(
            color: context.colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final VoidCallback onReset;
  const _Header({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: context.colors.blueGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customize Home',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pick the cards you use and drag to reorder',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onReset,
          child: Text(
            'Reset',
            style: TextStyle(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  const _SectionLabel({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: context.colors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _EmptyPinnedHint extends StatelessWidget {
  const _EmptyPinnedHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.dashboard_outlined, color: context.colors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No cards yet. Add one below, or tap Reset to bring back Class '
              'Notices and Bus Schedule.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pinned card row: colored icon, title, drag handle and remove button.
class _PinnedRow extends StatelessWidget {
  final HomeCard card;
  final int index;
  final VoidCallback onRemove;

  const _PinnedRow({
    super.key,
    required this.card,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.resolve(card.color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(card.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove ${card.title}',
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: context.colors.danger,
                size: 22,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Reorder ${card.title}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: context.colors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A catalog card that is not pinned yet.
class _AvailableRow extends StatelessWidget {
  final HomeCard card;
  final bool disabled;
  final VoidCallback onAdd;

  const _AvailableRow({
    required this.card,
    required this.disabled,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.colors.resolve(card.color);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(card.icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              card.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          if (card.membersOnly) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primary
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Members',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_rounded,
                  color: disabled
                      ? context.colors.textMuted
                      : context.colors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
