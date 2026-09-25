// Developed by Rajesh Biswas (rajeshbiswas.dev)

/// Outward-facing links surfaced in the About screen.
///
/// Every optional entry is `null` until the real destination is published, and
/// the About screen only renders a row for a link that exists. That is the whole
/// point of this file: the app can never show a "coming soon" tap target that
/// does nothing. To ship a link, set it here — the row appears automatically,
/// with no UI change.
class AppLinks {
  const AppLinks._();

  /// Public privacy policy. A hosted policy URL is also required by the Google
  /// Play listing for an app that stores student profiles, attendance and donor
  /// contact details, so this should be filled in before release.
  static const String? privacyPolicyUrl = null;

  /// Public terms of service.
  static const String? termsOfServiceUrl = null;

  /// Support inbox. Rendered as a `mailto:` row when set.
  static const String? contactEmail = null;

  /// Developer site — already credited in the app footer, so it is safe to link.
  static const String developerUrl = 'https://rajeshbiswas.dev';
}
