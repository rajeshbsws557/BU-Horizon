import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for lost & found items.
abstract interface class LostFoundRepository {
  List<LostFoundItem> get lostItems;
  List<LostFoundItem> get foundItems;
}

@Injectable(as: LostFoundRepository)
final class SampleLostFoundRepository implements LostFoundRepository {
  @override
  List<LostFoundItem> get lostItems => List.unmodifiable(
        SampleData.lostFound.where((e) => e.isLost),
      );

  @override
  List<LostFoundItem> get foundItems => List.unmodifiable(
        SampleData.lostFound.where((e) => !e.isLost),
      );
}
