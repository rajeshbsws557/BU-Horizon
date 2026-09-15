// Developed by Rajesh Biswas (rajeshbiswas.dev)
//
// WCAG AA contrast floor for the text roles, checked at the palette level.
//
// The widget-level accessibility guideline only renders the fallback variant, so
// a muted label that fails in "Purple Cipher" would never be caught there. This
// asserts the ratio arithmetic directly for every variant, in both modes,
// against every surface those labels actually sit on.
import 'dart:math' as math;

import 'package:bu_horizon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 contrast ratio. [Color.computeLuminance] is the spec's relative
/// luminance, so this is the published formula verbatim.
double contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = math.max(a, b);
  final darker = math.min(a, b);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  // AA for normal-sized text. Every text role checked here is used at well
  // under 18pt (muted captions run 10.5–12px), so the large-text exemption
  // does not apply.
  const minimumRatio = 4.5;

  for (final variant in AppThemeVariant.values) {
    for (final brightness in Brightness.values) {
      final palette = variant.palette(brightness);
      final modeName = brightness == Brightness.light ? 'light' : 'dark';

      final surfaces = <String, Color>{
        'background': palette.background,
        'surface': palette.surface,
        'surfaceAlt': palette.surfaceAlt,
        'cardSolid': palette.cardSolid,
      };
      final textRoles = <String, Color>{
        'textPrimary': palette.textPrimary,
        'textSecondary': palette.textSecondary,
        'textMuted': palette.textMuted,
      };

      group('${variant.label} ($modeName)', () {
        for (final text in textRoles.entries) {
          for (final surface in surfaces.entries) {
            test('${text.key} on ${surface.key}', () {
              final ratio = contrastRatio(text.value, surface.value);
              expect(
                ratio,
                greaterThanOrEqualTo(minimumRatio),
                reason:
                    '${variant.label} $modeName ${text.key} on ${surface.key} '
                    'is ${ratio.toStringAsFixed(2)}:1, below the '
                    '$minimumRatio:1 AA floor.',
              );
            });
          }
        }
      });
    }
  }
}
