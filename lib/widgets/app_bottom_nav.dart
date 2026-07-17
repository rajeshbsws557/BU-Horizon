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
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              _item(context, 0, Icons.home_rounded, 'Home'),
              _item(context, 1, Icons.search_rounded, 'Search'),
              _centerButton(),
              _item(context, 3, Icons.notifications_rounded, 'Alerts'),
              _item(context, 4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final active = index == currentIndex;
    final color = active ? AppColors.primary : context.colors.textMuted;
    return Expanded(
      child: Semantics(
        selected: active,
        label: label,
        button: true,
        child: InkWell(
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _centerButton() {
    return Expanded(
      child: Center(
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
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 + 0.30 * t),
                blurRadius: 14 + 10 * t,
                spreadRadius: 1 + t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: const Padding(
        padding: EdgeInsets.all(11),
        child: HorizonLogo(size: 30),
      ),
    );
  }
}
