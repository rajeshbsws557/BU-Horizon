// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/theme_cubit.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// Animated sun/moon icon button that seamlessly toggles between Light and Dark theme.
class ThemeToggleIcon extends StatelessWidget {
  final double size;
  const ThemeToggleIcon({super.key, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final isLight = themeState.isLight;
        return Semantics(
          button: true,
          label: isLight ? 'Switch to Dark Theme' : 'Switch to Light Theme',
          child: Tooltip(
            message: isLight ? 'Switch to Dark Theme' : 'Switch to Light Theme',
            child: Pressable(
              pressedScale: 0.90,
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<ThemeCubit>().toggleTheme();
              },
              child: ConstrainedBox(
                // Keep the visual at [size] but guarantee a >=44dp tap target.
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLight
                          ? context.colors.primary.withValues(alpha: 0.12)
                          : context.colors.surfaceAlt,
                      border: Border.all(
                        color: isLight
                            ? context.colors.primary.withValues(alpha: 0.3)
                            : context.colors.border,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) {
                          return RotationTransition(
                            turns: Tween<double>(begin: 0.75, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: Icon(
                          isLight
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          key: ValueKey<bool>(isLight),
                          size: size * 0.52,
                          color: isLight
                              ? context.colors.primary
                              : context.colors.gold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full tile row for Profile/Settings screen to toggle theme with label.
class ThemeToggleRow extends StatelessWidget {
  const ThemeToggleRow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final isLight = themeState.isLight;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<ThemeCubit>().toggleTheme();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLight
                            ? context.colors.primary.withValues(alpha: 0.15)
                            : context.colors.gold.withValues(alpha: 0.15),
                      ),
                      child: Icon(
                        isLight
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: isLight ? context.colors.primary : context.colors.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance Theme',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLight
                                ? 'Light Mode'
                                : 'Dark Mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: isLight,
                      activeThumbColor: context.colors.primary,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        context.read<ThemeCubit>().toggleTheme();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Palette picker for the Profile screen.
///
/// Lists every [AppThemeVariant] as a swatch card. Selection is local-only
/// (persisted in [LocalStore]), so it works identically for guests and
/// registered users — no account required.
class ThemeSelectorSection extends StatelessWidget {
  const ThemeSelectorSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final brightness =
            themeState.isLight ? Brightness.light : Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(16),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.primary.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: context.colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color Theme',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          themeState.variant.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Two-per-row grid built from plain Rows + Expanded. A
              // LayoutBuilder/Wrap here would break the guest view, which nests
              // this section inside an IntrinsicHeight (LayoutBuilder cannot
              // report intrinsic dimensions).
              for (var i = 0; i < AppThemeVariant.values.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i;
                          j < i + 2 && j < AppThemeVariant.values.length;
                          j++) ...[
                        if (j > i) const SizedBox(width: 10),
                        Expanded(
                          child: _VariantSwatch(
                            variant: AppThemeVariant.values[j],
                            brightness: brightness,
                            selected:
                                themeState.variant == AppThemeVariant.values[j],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context
                                  .read<ThemeCubit>()
                                  .setVariant(AppThemeVariant.values[j]);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A single palette card: preview swatches + label + selected state.
class _VariantSwatch extends StatelessWidget {
  final AppThemeVariant variant;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  const _VariantSwatch({
    required this.variant,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = variant.palette(brightness);

    return Semantics(
      button: true,
      selected: selected,
      label: '${variant.label} theme. ${variant.description}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? context.colors.primary
                    : context.colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini mock of the palette: background block with accent chips.
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.border),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Row(
                    children: [
                      _Dot(color: palette.primary),
                      const SizedBox(width: 5),
                      _Dot(color: palette.accentCyan),
                      const SizedBox(width: 5),
                      _Dot(color: palette.danger),
                      const Spacer(),
                      Container(
                        width: 26,
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.textSecondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        variant.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected
                              ? context.colors.primary
                              : context.colors.textPrimary,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: context.colors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  variant.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
