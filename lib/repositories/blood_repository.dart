import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

class BloodDonorRegistration {
  final BloodGroup group;
  final String contact;
  final DateTime? lastDonated;
  final bool available;

  const BloodDonorRegistration({
    required this.group,
    required this.contact,
    required this.lastDonated,
    required this.available,
  });
}

/// Repository for blood requests and in-app responses.
abstract interface class BloodRepository {
  Future<List<BloodRequest>> fetchRequests();

  /// The urgent request currently in its 6-hour home-screen spotlight window
  /// (the oldest still-active urgent open request), or null if none. Backed by
  /// the `active_urgent_blood_requests` view, which enforces the 6h cutoff.
  Future<BloodRequest?> fetchActiveUrgentRequest();

  Future<void> createRequest({
    required BloodGroup group,
    required int units,
    required String contact,
    required String location,
    String? note,
    bool isUrgent = false,
  });

  /// Record an in-app response to [requestId] from the signed-in user.
  Future<void> respond(String requestId, {String? message, String? contact});

  /// Responses to [requestId]; only the requester (and the responders
  /// themselves) can see these — enforced by RLS.
  Future<List<ResponseItem>> fetchResponses(String requestId);

  /// Mark a blood request as fulfilled (requester only).
  Future<void> markFulfilled(String requestId);

  Future<BloodDonorRegistration?> fetchMyDonorRegistration();

  Future<void> saveDonorRegistration(BloodDonorRegistration registration);
}

@Injectable(as: BloodRepository)
final class SampleBloodRepository implements BloodRepository {
  BloodDonorRegistration? _registration;
  @override
  Future<List<BloodRequest>> fetchRequests() async =>
      List.unmodifiable(SampleData.bloodRequests);

  @override
  Future<BloodRequest?> fetchActiveUrgentRequest() async => null;

  @override
  Future<void> createRequest({
    required BloodGroup group,
    required int units,
    required String contact,
    required String location,
    String? note,
    bool isUrgent = false,
  }) async {
    throw StateError('Backend not configured');
  }

  @override
  Future<void> respond(String requestId, {String? message, String? contact}) async {
    throw StateError('Backend not configured');
  }

  @override
  Future<List<ResponseItem>> fetchResponses(String requestId) async => const [];

  @override
  Future<void> markFulfilled(String requestId) async {
    throw StateError('Backend not configured');
  }

  @override
  Future<BloodDonorRegistration?> fetchMyDonorRegistration() async =>
      _registration;

  @override
  Future<void> saveDonorRegistration(
    BloodDonorRegistration registration,
  ) async {
    _registration = registration;
  }
}
