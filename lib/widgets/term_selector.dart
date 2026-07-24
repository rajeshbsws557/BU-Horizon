import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TermSelector extends StatelessWidget {
  final List<int> terms;
  final int? selectedTerm;
  final ValueChanged<int> onSelected;

  const TermSelector({
    super.key,
    required this.terms,
    required this.selectedTerm,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (terms.length <= 1) return const SizedBox.shrink();
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
            label: Text('Semester $term'),
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
