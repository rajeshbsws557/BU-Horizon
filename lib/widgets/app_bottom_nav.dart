import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'horizon_logo.dart';

/// Global bottom navigation with an elevated center logo hub.
/// Indices: 0 Home, 1 Search, 2 Center hub, 3 Alerts, 4 Profile.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _item(context, 0, Icons.home_rounded, 'Home'),
            _item(context, 1, Icons.groups_rounded, 'Club'),
            _centerButton(),
            _item(context, 3, Icons.campaign_rounded, 'Notices'),
            _item(context, 4, Icons.person_rounded, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final active = index == currentIndex;
    final color = active ? context.colors.primary : context.colors.textMuted;
    // Cap label scaling so the bar stays compact at large OS text sizes.
    final clampedScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.3);
    return Expanded(
      child: Semantics(
        selected: active,
        label: label,
        button: true,
        child: InkWell(
          onTap: () => onTap(index),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 9),
                AnimatedScale(
                  scale: active ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    textScaler: TextScaler.linear(clampedScale),
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return Expanded(
      // heightFactor: 1 makes Center hug the hub instead of expanding to the
      // full height the bottomNavigationBar slot offers (which would blow the
      // bar up to fill the whole screen).
      child: Center(
        heightFactor: 1,
        child: Semantics(
          label: 'Quick access hub',
          button: true,
          child: GestureDetector(
            onTap: () => onTap(2),
            child: _PulsingHub(),
          ),
        ),
      ),
    );
  }
}

/// Center hub with a slow breathing glow, so the brand mark feels alive.
class _PulsingHub extends StatefulWidget {
  @override
  State<_PulsingHub> createState() => _PulsingHubState();
}

class _PulsingHubState extends State<_PulsingHub>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.surface,
            border: Border.all(color: context.colors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary
                    .withValues(alpha: 0.25 + 0.30 * t),
                blurRadius: 14 + 10 * t,
                spreadRadius: 1 + t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(3),
        child: HorizonLogo(size: 46),
      ),
    );
  }
}
