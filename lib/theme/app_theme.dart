import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Text/icon ink that stays legible on a saturated [fill].
///
/// Picks whichever of dark ink or white actually has more contrast against the
/// fill, so a filled chip stays readable in every palette and mode instead of
/// hard-coding white (which fails on the brighter accents).
Color inkOn(Color fill) {
  const darkInk = Color(0xFF06121F);
  return _contrastRatio(darkInk, fill) > _contrastRatio(Colors.white, fill)
      ? darkInk
      : Colors.white;
}

double _contrastRatio(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

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

  // --- Cybersecurity club palettes ------------------------------------------
  // Four brand palettes, each shipped as a dark (primary) and a light variant
  // so the light/dark switch keeps working whichever theme is selected.

  /// Theme 1 — Matrix Green: classic terminal / hacker aesthetic.
  static const AppThemeColors matrixDark = AppThemeColors(
    background: Color(0xFF0D0D0D),
    surface: Color(0xFF161616),
    surfaceAlt: Color(0xFF1E1E1E),
    cardSolid: Color(0xFF1A1A1A),
    primary: Color(0xFF00E63B),
    primaryDark: Color(0xFF00B32E),
    primarySoft: Color(0xFF0C2A15),
    accentCyan: Color(0xFF00E5A0),
    success: Color(0xFF00E63B),
    danger: Color(0xFFFF4D4D),
    warning: Color(0xFFFFB000),
    gold: Color(0xFFFFC107),
    purple: Color(0xFF9B6DFF),
    textPrimary: Color(0xFFE9FFE9),
    textSecondary: Color(0xFF9DB39D),
    textMuted: Color(0xFF7B8B7B),
    border: Color(0xFF2A2A2A),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00E63B), Color(0xFF00B32E)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF4D4D), Color(0xFFB01F1F)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF16241A), Color(0xFF0D0D0D)],
    ),
  );

  static const AppThemeColors matrixLight = AppThemeColors(
    background: Color(0xFFF2F7F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9F2E9),
    cardSolid: Color(0xFFFFFFFF),
    primary: Color(0xFF0A8F32),
    primaryDark: Color(0xFF067A28),
    primarySoft: Color(0xFFDCF3E1),
    accentCyan: Color(0xFF0E9B8A),
    success: Color(0xFF0A8F32),
    danger: Color(0xFFC62828),
    warning: Color(0xFFB26A00),
    gold: Color(0xFF96742B),
    purple: Color(0xFF6D3FC4),
    textPrimary: Color(0xFF10190F),
    textSecondary: Color(0xFF44554A),
    textMuted: Color(0xFF607064),
    border: Color(0xFFD3E2D5),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A8F32), Color(0xFF067A28)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC62828), Color(0xFF9B1C1C)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE3F5E7), Color(0xFFF2F7F2)],
    ),
  );

  /// Theme 2 — Deep Blue Cyber: professional, enterprise SOC look.
  static const AppThemeColors cyberDark = AppThemeColors(
    background: Color(0xFF0A0E1A),
    surface: Color(0xFF141B2E),
    surfaceAlt: Color(0xFF1B2740),
    cardSolid: Color(0xFF141B2E),
    primary: Color(0xFF00B4E6),
    primaryDark: Color(0xFF0084FF),
    primarySoft: Color(0xFF10243F),
    accentCyan: Color(0xFF22E3FF),
    success: Color(0xFF22C55E),
    danger: Color(0xFFFF4757),
    warning: Color(0xFFF5A623),
    gold: Color(0xFFFFC107),
    purple: Color(0xFF7C6BFF),
    textPrimary: Color(0xFFE1E7F5),
    textSecondary: Color(0xFF9FB0CC),
    textMuted: Color(0xFF8190AA),
    border: Color(0xFF22304D),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00D4FF), Color(0xFF0084FF)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF4757), Color(0xFFB3202D)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF17233D), Color(0xFF0A0E1A)],
    ),
  );

  static const AppThemeColors cyberLight = AppThemeColors(
    background: Color(0xFFF2F6FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8F0FA),
    cardSolid: Color(0xFFFFFFFF),
    primary: Color(0xFF0072D8),
    primaryDark: Color(0xFF005AAE),
    primarySoft: Color(0xFFDCEBFB),
    accentCyan: Color(0xFF0288D1),
    success: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    gold: Color(0xFFB8935A),
    purple: Color(0xFF6D4BE0),
    textPrimary: Color(0xFF0B1524),
    textSecondary: Color(0xFF46586F),
    textMuted: Color(0xFF5D6C81),
    border: Color(0xFFD6E2F0),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0072D8), Color(0xFF005AAE)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE1EEFB), Color(0xFFF2F6FC)],
    ),
  );

  /// Theme 3 — Purple Cipher: elite, distinctive club identity.
  static const AppThemeColors purpleDark = AppThemeColors(
    background: Color(0xFF0B0813),
    surface: Color(0xFF160D24),
    surfaceAlt: Color(0xFF1E1130),
    cardSolid: Color(0xFF160D24),
    primary: Color(0xFFA855F7),
    primaryDark: Color(0xFF7C3AED),
    primarySoft: Color(0xFF241539),
    accentCyan: Color(0xFF22D3EE),
    success: Color(0xFF34D399),
    danger: Color(0xFFF43F5E),
    warning: Color(0xFFFBBF24),
    gold: Color(0xFFFBBF24),
    purple: Color(0xFFC084FC),
    textPrimary: Color(0xFFE8E4F3),
    textSecondary: Color(0xFFBFB5D0),
    textMuted: Color(0xFF8E82A3),
    border: Color(0xFF2C1D43),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF43F5E), Color(0xFFA51E38)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF241539), Color(0xFF0B0813)],
    ),
  );

  static const AppThemeColors purpleLight = AppThemeColors(
    background: Color(0xFFF8F5FE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0E9FB),
    cardSolid: Color(0xFFFFFFFF),
    primary: Color(0xFF7C3AED),
    primaryDark: Color(0xFF6D28D9),
    primarySoft: Color(0xFFEDE3FE),
    accentCyan: Color(0xFF0891B2),
    success: Color(0xFF059669),
    danger: Color(0xFFE11D48),
    warning: Color(0xFFD97706),
    gold: Color(0xFFB8935A),
    purple: Color(0xFF7C3AED),
    textPrimary: Color(0xFF17102A),
    textSecondary: Color(0xFF52466B),
    textMuted: Color(0xFF6F6488),
    border: Color(0xFFE3D9F5),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE11D48), Color(0xFFB91C3C)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEFE6FD), Color(0xFFF8F5FE)],
    ),
  );

  /// Theme 4 — Stealth Amber: terminal-ops amber on true black.
  static const AppThemeColors amberDark = AppThemeColors(
    background: Color(0xFF0C0C0C),
    surface: Color(0xFF161616),
    surfaceAlt: Color(0xFF1E1E1E),
    cardSolid: Color(0xFF161616),
    primary: Color(0xFFFFB000),
    primaryDark: Color(0xFFE09600),
    primarySoft: Color(0xFF2A2210),
    accentCyan: Color(0xFF35B8C4),
    success: Color(0xFF3FB950),
    danger: Color(0xFFE5484D),
    warning: Color(0xFFFFB000),
    gold: Color(0xFFFFC94D),
    purple: Color(0xFFA371F7),
    textPrimary: Color(0xFFF0EDE8),
    textSecondary: Color(0xFF9C9691),
    textMuted: Color(0xFF8B8782),
    border: Color(0xFF2A2A2A),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFB000), Color(0xFFE09600)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE5484D), Color(0xFF9E2226)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF241E12), Color(0xFF0C0C0C)],
    ),
  );

  static const AppThemeColors amberLight = AppThemeColors(
    background: Color(0xFFFAF8F4),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF2EEE6),
    cardSolid: Color(0xFFFFFFFF),
    primary: Color(0xFFB26A00),
    primaryDark: Color(0xFF8F5400),
    primarySoft: Color(0xFFFBEFD6),
    accentCyan: Color(0xFF0E7490),
    success: Color(0xFF12803C),
    danger: Color(0xFFC62828),
    warning: Color(0xFFB26A00),
    gold: Color(0xFF96742B),
    purple: Color(0xFF6D3FC4),
    textPrimary: Color(0xFF1A1713),
    textSecondary: Color(0xFF524B42),
    textMuted: Color(0xFF6E665C),
    border: Color(0xFFE5DED2),
    blueGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFB26A00), Color(0xFF8F5400)],
    ),
    bloodGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFC62828), Color(0xFF9B1C1C)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF6EFE1), Color(0xFFFAF8F4)],
    ),
  );

  /// Defaults kept as aliases so existing call sites (and the `context.colors`
  /// fallback) keep compiling while the selected variant drives the real theme.
  static const AppThemeColors dark = cyberDark;
  static const AppThemeColors light = cyberLight;
}

/// The four selectable cybersecurity-club palettes.
///
/// A variant only chooses *colors*: the light/dark switch is orthogonal, so
/// every variant ships both a dark and a light palette.
enum AppThemeVariant {
  matrixGreen(
    id: 'matrix_green',
    label: 'Matrix Green',
    description: 'Classic terminal hacker green',
    dark: AppThemeColors.matrixDark,
    light: AppThemeColors.matrixLight,
  ),
  cyberBlue(
    id: 'cyber_blue',
    label: 'Cyber Blue',
    description: 'Professional SOC dashboard blue',
    dark: AppThemeColors.cyberDark,
    light: AppThemeColors.cyberLight,
  ),
  purpleCipher(
    id: 'purple_cipher',
    label: 'Purple Cipher',
    description: 'Elite, distinctive club identity',
    dark: AppThemeColors.purpleDark,
    light: AppThemeColors.purpleLight,
  ),
  stealthAmber(
    id: 'stealth_amber',
    label: 'Stealth Amber',
    description: 'Amber on true black, easiest on the eyes',
    dark: AppThemeColors.amberDark,
    light: AppThemeColors.amberLight,
  );

  const AppThemeVariant({
    required this.id,
    required this.label,
    required this.description,
    required this.dark,
    required this.light,
  });

  /// Stable key used for persistence — never rename these strings.
  final String id;
  final String label;
  final String description;
  final AppThemeColors dark;
  final AppThemeColors light;

  AppThemeColors palette(Brightness brightness) =>
      brightness == Brightness.light ? light : dark;

  /// The variant to fall back to when nothing has been chosen (or a stored id
  /// is no longer recognised).
  static const AppThemeVariant fallback = AppThemeVariant.cyberBlue;

  static AppThemeVariant fromId(String? id) {
    for (final variant in AppThemeVariant.values) {
      if (variant.id == id) return variant;
    }
    return fallback;
  }
}

/// Const sentinel colors used as *semantic tokens* inside const data models
/// (which have no BuildContext). Never render these directly — resolve them
/// against the live theme with [AppThemeColorsResolve.resolve].
class AppColorToken {
  AppColorToken._();
  static const Color primary = Color(0xFF2E7DF6);
  static const Color accentCyan = Color(0xFF4FC3F7);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFE23744);
  static const Color warning = Color(0xFFF5A623);
  static const Color gold = Color(0xFFFFC107);
  static const Color purple = Color(0xFF9B6DFF);
}

extension AppThemeColorsResolve on AppThemeColors {
  /// Maps an [AppColorToken] sentinel stored in const data to the live theme
  /// color. Unknown colors pass through unchanged.
  Color resolve(Color token) {
    if (token == AppColorToken.primary) return primary;
    if (token == AppColorToken.accentCyan) return accentCyan;
    if (token == AppColorToken.success) return success;
    if (token == AppColorToken.danger) return danger;
    if (token == AppColorToken.warning) return warning;
    if (token == AppColorToken.gold) return gold;
    if (token == AppColorToken.purple) return purple;
    return token;
  }
}

extension AppThemeColorsContext on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.dark;
  bool get isLight => Theme.of(this).brightness == Brightness.light;
}

/// Accessor for the active theme's colors. All rendering must go through
/// `AppColors.of(context)` / `context.colors` so light and dark modes stay
/// in sync — the old static dark-palette constants have been removed.
class AppColors {
  AppColors._();

  static AppThemeColors of(BuildContext context) => context.colors;
}

/// Single source of truth for the standard card look, context-aware.
BoxDecoration cardDecoration({Color? color, double? radius, required BuildContext context}) {
  final c = context.colors;
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

  /// Builds the [ThemeData] for a palette + brightness pair.
  ///
  /// Both the light and dark themes of every variant come through here, so the
  /// component styling stays identical and only the colors differ.
  static ThemeData _build(AppThemeColors c, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final base = isLight
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      primaryColor: c.primary,
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: c.primary,
        secondary: c.accentCyan,
        surface: c.surface,
        error: c.danger,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? c.surface : c.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: c.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: c.textPrimary,
        ),
      ),
      dividerColor: c.border,
      splashColor: c.primary.withValues(alpha: 0.08),
      highlightColor: c.primary.withValues(alpha: 0.05),
      extensions: [c],
    );
  }

  /// Dark theme for [variant].
  static ThemeData darkOf(AppThemeVariant variant) =>
      _build(variant.dark, Brightness.dark);

  /// Light theme for [variant].
  static ThemeData lightOf(AppThemeVariant variant) =>
      _build(variant.light, Brightness.light);

  /// Default-variant themes, kept for call sites that don't care which palette
  /// is selected (tests, previews).
  static ThemeData get dark => darkOf(AppThemeVariant.fallback);
  static ThemeData get light => lightOf(AppThemeVariant.fallback);
}

