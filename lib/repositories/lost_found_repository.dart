import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for lost & found items and in-app responses.
abstract interface class LostFoundRepository {
  Future<List<LostFoundItem>> fetchItems();

  Future<void> report({
    required bool isLost,
    required String title,
    required String description,
    required String location,
  });

  /// Record an in-app response (e.g. "I found it" / "that's mine").
  Future<void> respond(String itemId, {String? message, String? contact});

  /// Responses to [itemId]; visible to the reporter and each responder only.
  Future<List<ResponseItem>> fetchResponses(String itemId);
}

@Injectable(as: LostFoundRepository)
final class SampleLostFoundRepository implements LostFoundRepository {
  @override
  Future<List<LostFoundItem>> fetchItems() async =>
      List.unmodifiable(SampleData.lostFound);

  @override
  Future<void> report({
    required bool isLost,
    required String title,
    required String description,
    required String location,
  }) async {
    throw StateError('Backend not configured');
  }

  @override
  Future<void> respond(String itemId, {String? message, String? contact}) async {
    throw StateError('Backend not configured');
  }

  @override
  Future<List<ResponseItem>> fetchResponses(String itemId) async => const [];
}
