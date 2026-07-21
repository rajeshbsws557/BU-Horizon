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
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isLight = themeMode == ThemeMode.light;
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
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isLight = themeMode == ThemeMode.light;
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
