import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TermSelector extends StatelessWidget {
  final List<int> terms;
  final int? selectedTerm;
  final ValueChanged<int> onSelected;

  /// Label for a single term unit, e.g. 'Semester' or 'Year'.
  /// Defaults to 'Semester' for backward compatibility.
  final String termLabel;

  const TermSelector({
    super.key,
    required this.terms,
    required this.selectedTerm,
    required this.onSelected,
    this.termLabel = 'Semester',
  });

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) return const SizedBox.shrink();
    return SizedBox(

      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: terms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final term = terms[index];
          final isSelected = term == selectedTerm;
          return ChoiceChip(
            label: Text('$termLabel $term'),
            selected: isSelected,
            onSelected: (_) => onSelected(term),
            selectedColor: context.colors.primary.withValues(alpha: 0.15),
            backgroundColor: context.colors.surfaceAlt,
            labelStyle: TextStyle(
              color: isSelected
                  ? context.colors.primary
                  : context.colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            side: BorderSide(
              color: isSelected
                  ? context.colors.primary.withValues(alpha: 0.5)
                  : context.colors.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          );
        },
      ),
    );
  }
}
