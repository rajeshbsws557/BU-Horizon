import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for blood requests and in-app responses.
abstract interface class BloodRepository {
  Future<List<BloodRequest>> fetchRequests();

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
}

@Injectable(as: BloodRepository)
final class SampleBloodRepository implements BloodRepository {
  @override
  Future<List<BloodRequest>> fetchRequests() async =>
      List.unmodifiable(SampleData.bloodRequests);

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
}
