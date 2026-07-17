import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens: spacing + radii. Use these instead of scattering magic
/// numbers, so the whole app stays visually consistent and easy to retune.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class AppRadii {
  AppRadii._();
  static const double sm = 8;
  static const double md = 12;
  static const double card = 14;
  static const double lg = 18;
}

/// Dynamic theme extension defining all colors used across both Light and Dark modes.
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color cardSolid;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color accentCyan;
  final Color success;
  final Color danger;
  final Color warning;
  final Color gold;
  final Color purple;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final LinearGradient blueGradient;
  final LinearGradient bloodGradient;
  final LinearGradient heroGradient;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.cardSolid,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.accentCyan,
    required this.success,
    required this.danger,
    required this.warning,
    required this.gold,
    required this.purple,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.blueGradient,
    required this.bloodGradient,
    required this.heroGradient,
  });

  @override
  ThemeExtension<AppThemeColors> copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? cardSolid,
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? accentCyan,
    Color? success,
    Color? danger,
    Color? warning,
    Color? gold,
    Color? purple,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    LinearGradient? blueGradient,
    LinearGradient? bloodGradient,
    LinearGradient? heroGradient,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      cardSolid: cardSolid ?? this.cardSolid,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      accentCyan: accentCyan ?? this.accentCyan,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      gold: gold ?? this.gold,
      purple: purple ?? this.purple,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      blueGradient: blueGradient ?? this.blueGradient,
      bloodGradient: bloodGradient ?? this.bloodGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  ThemeExtension<AppThemeColors> lerp(
      covariant ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      cardSolid: Color.lerp(cardSolid, other.cardSolid, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      blueGradient: LinearGradient.lerp(blueGradient, other.blueGradient, t)!,
      bloodGradient:
          LinearGradient.lerp(bloodGradient, other.bloodGradient, t)!,
      heroGradient:
          LinearGradient.lerp(heroGradient, other.heroGradient, t)!,
    );
  }

  static const AppThemeColors dark = AppThemeColors(
    background: Color(0xFF05070E),
    surface: Color(0xFF0E1524),
    surfaceAlt: Color(0xFF141C2E),
    cardSolid: Color(0xFF131B2C),
    primary: Color(0xFF2E7DF6),
    primaryDark: Color(0xFF1E63D6),
    primarySoft: Color(0xFF1B2C4E),
    accentCyan: Color(0xFF4FC3F7),
    success: Color(0xFF22C55E),
    danger: Color(0xFFE23744),
    warning: Color(0xFFF5A623),
    gold: Color(0xFFFFC107),
    purple: Color(0xFF9B6DFF),
    textPrimary: Color(0xFFF3F6FF),
    textSecondary: Color(0xFF9AA6BF),
    textMuted: Color(0xFF7E8CA8),
    border: Color(0xFF20293D),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E7DF6), Color(0xFF1E63D6)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE23744), Color(0xFF9E1C27)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF17233D), Color(0xFF0C1526)],
    ),
  );

  static const AppThemeColors light = AppThemeColors(
    background: Color(0xFFF4F6FB),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF2F8),
    cardSolid: Color(0xFFFFFFFF),
    primary: Color(0xFF1B6BF3),
    primaryDark: Color(0xFF1253C4),
    primarySoft: Color(0xFFE2EDFF),
    accentCyan: Color(0xFF0288D1),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    gold: Color(0xFFB8935A),
    purple: Color(0xFF7C3AED),
    textPrimary: Color(0xFF0E1626),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    border: Color(0xFFDDE3F0),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B6BF3), Color(0xFF1253C4)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8F0FE), Color(0xFFF3F6FF)],
    ),
  );
}

extension AppThemeColorsContext on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;
  bool get isLight => Theme.of(this).brightness == Brightness.light;
}

/// Central palette + theme for BU Horizon.
/// Keeps static constants for backwards compatibility and const constructors,
/// plus `of(context)` for dynamic theme switching.
class AppColors {
  AppColors._();

  static AppThemeColors of(BuildContext context) => context.colors;

  static const Color background = Color(0xFF05070E);
  static const Color surface = Color(0xFF0E1524);
  static const Color surfaceAlt = Color(0xFF141C2E);
  static const Color cardSolid = Color(0xFF131B2C);

  static const Color primary = Color(0xFF2E7DF6);
  static const Color primaryDark = Color(0xFF1E63D6);
  static const Color primarySoft = Color(0xFF1B2C4E);
  static const Color accentCyan = Color(0xFF4FC3F7);

  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFE23744);
  static const Color warning = Color(0xFFF5A623);
  static const Color gold = Color(0xFFFFC107);
  static const Color purple = Color(0xFF9B6DFF);

  static const Color textPrimary = Color(0xFFF3F6FF);
  static const Color textSecondary = Color(0xFF9AA6BF);
  static const Color textMuted = Color(0xFF7E8CA8);

  static const Color border = Color(0xFF20293D);

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7DF6), Color(0xFF1E63D6)],
  );

  static const LinearGradient bloodGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE23744), Color(0xFF9E1C27)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF17233D), Color(0xFF0C1526)],
  );
}

/// Single source of truth for the standard card look, now context-aware.
BoxDecoration cardDecoration({Color? color, double? radius, BuildContext? context}) {
  final c = context?.colors ?? AppThemeColors.dark;
  return BoxDecoration(
    color: color ?? c.surfaceAlt,
    borderRadius: BorderRadius.circular(radius ?? AppRadii.card),
    border: Border.all(color: c.border),
  );
}

/// Reusable surface card. Adapts dynamically to current light or dark theme.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.radius,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: cardDecoration(color: color, radius: radius, context: context),
        child: child,
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppThemeColors.dark.textPrimary,
      displayColor: AppThemeColors.dark.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppThemeColors.dark.background,
      primaryColor: AppThemeColors.dark.primary,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: AppThemeColors.dark.primary,
        secondary: AppThemeColors.dark.accentCyan,
        surface: AppThemeColors.dark.surface,
        error: AppThemeColors.dark.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppThemeColors.dark.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppThemeColors.dark.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppThemeColors.dark.textPrimary,
        ),
      ),
      dividerColor: AppThemeColors.dark.border,
      splashColor: AppThemeColors.dark.primary.withValues(alpha: 0.08),
      highlightColor: AppThemeColors.dark.primary.withValues(alpha: 0.05),
      extensions: const [AppThemeColors.dark],
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppThemeColors.light.textPrimary,
      displayColor: AppThemeColors.light.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppThemeColors.light.background,
      primaryColor: AppThemeColors.light.primary,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        primary: AppThemeColors.light.primary,
        secondary: AppThemeColors.light.accentCyan,
        surface: AppThemeColors.light.surface,
        error: AppThemeColors.light.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppThemeColors.light.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppThemeColors.light.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppThemeColors.light.textPrimary,
        ),
      ),
      dividerColor: AppThemeColors.light.border,
      splashColor: AppThemeColors.light.primary.withValues(alpha: 0.08),
      highlightColor: AppThemeColors.light.primary.withValues(alpha: 0.05),
      extensions: const [AppThemeColors.light],
    );
  }
}

