import 'package:injectable/injectable.dart';

/// Categories of harm a student can report through the legal-help flow.
enum ReportCategory {
  cyberbullying('cyberbullying', 'Cyber-bullying'),
  harassment('harassment', 'Harassment'),
  threats('threats', 'Threats / intimidation'),
  impersonation('impersonation', 'Impersonation / fake account'),
  doxxing('doxxing', 'Doxxing / privacy breach'),
  stalking('stalking', 'Stalking'),
  other('other', 'Other');

  const ReportCategory(this.wire, this.label);

  /// Value persisted in the Postgres `report_category` enum.
  final String wire;
  final String label;
}

/// A completed legal-help / cyber-bullying report ready for submission.
class LegalHelpDraft {
  final ReportCategory category;
  final String description;
  final bool isAnonymous;
  final String? reporterName;
  final String? contactEmail;
  final String? contactPhone;
  final String? incidentPlatform;
  final DateTime? incidentDate;
  final String? location;
  final String? involvedParties;
  final String? evidenceUrl;

  const LegalHelpDraft({
    required this.category,
    required this.description,
    this.isAnonymous = false,
    this.reporterName,
    this.contactEmail,
    this.contactPhone,
    this.incidentPlatform,
    this.incidentDate,
    this.location,
    this.involvedParties,
    this.evidenceUrl,
  });
}

/// Submits confidential cyber-bullying / harassment reports for super-admin
/// (university authority) review.
abstract interface class LegalHelpRepository {
  Future<void> submitReport(LegalHelpDraft draft);
}

/// UI-only / test implementation. Accepts the draft and does nothing.
@Injectable(as: LegalHelpRepository)
final class SampleLegalHelpRepository implements LegalHelpRepository {
  @override
  Future<void> submitReport(LegalHelpDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}
