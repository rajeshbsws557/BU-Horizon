// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A beautiful bottom-sheet history picker that lets a student jump between
/// their current term and any previous one. Used by the Class Notices, Exam
/// Schedule, Attendance and Resources screens via [showTermHistorySheet].
///
/// [availableTerms] are the terms that actually have content; [currentTerm] is
/// the batch's live term (highlighted as "Current"). Selecting a term returns
/// it to the caller, which then filters its list to that term.
Future<int?> showTermHistorySheet(
  BuildContext context, {
  required List<int> availableTerms,
  required int? selectedTerm,
  required int? currentTerm,
  String termLabel = 'Semester',
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TermHistorySheet(
      availableTerms: availableTerms,
      selectedTerm: selectedTerm,
      currentTerm: currentTerm,
      termLabel: termLabel,
    ),
  );
}

class _TermHistorySheet extends StatelessWidget {
  final List<int> availableTerms;
  final int? selectedTerm;
  final int? currentTerm;
  final String termLabel;

  const _TermHistorySheet({
    required this.availableTerms,
    required this.selectedTerm,
    required this.currentTerm,
    required this.termLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Show every term the batch has reached, even if it has no content yet, so
    // history always spans 1..current. Merge with terms that carry content.
    final terms = <int>{
      ...availableTerms,
      if (currentTerm != null)
        for (var t = 1; t <= currentTerm!; t++) t,
    }.toList()..sort((a, b) => b.compareTo(a)); // newest first

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: context.colors.blueGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
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
                        'View History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Jump to your current or a previous ${termLabel.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (terms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No history available yet.',
                    style: TextStyle(color: context.colors.textMuted),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: terms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final term = terms[index];
                    final isSelected = term == selectedTerm;
                    final isCurrent = term == currentTerm;
                    return _TermTile(
                      term: term,
                      termLabel: termLabel,
                      isSelected: isSelected,
                      isCurrent: isCurrent,
                      onTap: () => Navigator.pop(context, term),
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

class _TermTile extends StatelessWidget {
  final int term;
  final String termLabel;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _TermTile({
    required this.term,
    required this.termLabel,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.colors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.12)
                : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.5)
                  : context.colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$term',
                  style: TextStyle(
                    color: isSelected ? Colors.white : accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$termLabel $term',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.success
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Current',
                              style: TextStyle(
                                color: context.colors.success,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCurrent
                          ? 'Your active ${termLabel.toLowerCase()}'
                          : 'Past ${termLabel.toLowerCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: accent, size: 22)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
