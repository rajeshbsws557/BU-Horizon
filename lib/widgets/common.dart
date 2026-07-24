import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// Caps content width on wide viewports (web/desktop) and centers it, so
/// screens don't stretch full-bleed the way [home_screen.dart] and
/// [main_scaffold.dart] already avoid.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsivePage({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Underline-style segmented tabs (All Routes / My Routes / Favorites, etc.).
/// The active underline slides between tabs instead of snapping.
class SegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final tabWidth = c.maxWidth / tabs.length;
        return Stack(
          children: [
            Row(
              children: List.generate(tabs.length, (i) {
                final active = i == selected;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: active ? context.colors.primary : context.colors.textSecondary,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 14,
                        ),
                        child: Text(tabs[i], textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                );
              }),
            ),
            AnimatedPositionedDirectional(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              start: selected * tabWidth,
              bottom: 0,
              child: Container(
                width: tabWidth,
                alignment: Alignment.center,
                child: Container(
                  width: tabWidth * 0.5,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Rounded search input matching the design.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  const SearchField({super.key, required this.hint, this.onChanged, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: context.colors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        ),
      ),
    );
  }
}

/// Primary full-width action button: gradient, glow, press-scale + haptic.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1.0,
      child: Pressable(
        pressedScale: disabled ? 1.0 : 0.98,
        onTap: onPressed,
        semanticLabel: label,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: context.colors.blueGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: disabled
                ? const []
                : [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple centered screen header for tab pages (no back button).
class TabHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final String? subtitle;
  const TabHeader({super.key, required this.title, this.actions = const [], this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A soft "glass" hero surface: translucent gradient fill with a top-light
/// border for depth. Intentionally does NOT use BackdropFilter, because the
/// app sits on an opaque background, so a real blur pass would cost GPU time
/// while blurring nothing. This gives the same look at a fraction of the cost.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ??
            (context.isLight
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.70),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  )),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: context.isLight
              ? context.colors.border
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: child,
    );
  }
}

/// Friendly empty state for filtered lists with no results.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(icon, color: context.colors.textMuted, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A shimmering skeleton block for loading states.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;
  const Skeleton({super.key, this.height = 16, this.width, this.radius});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.radius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * _c.value, 0),
              end: Alignment(1 - 2 * _c.value, 0),
              colors: [
                context.colors.surfaceAlt,
                context.colors.surface,
                context.colors.surfaceAlt,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small helper to show a transient confirmation.
void showToast(BuildContext context, String message) {
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(
        message,
        style: TextStyle(color: context.colors.textPrimary),
      ),
      backgroundColor: context.colors.surfaceAlt,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}
