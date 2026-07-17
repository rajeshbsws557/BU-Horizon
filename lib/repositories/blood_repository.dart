import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for blood needs and donation requests.
abstract interface class BloodRepository {
  BloodNeed get urgentNeed;
  List<BloodRequest> get requests;
}

@Injectable(as: BloodRepository)
final class SampleBloodRepository implements BloodRepository {
  @override
  BloodNeed get urgentNeed => SampleData.urgentBloodNeed;

  @override
  List<BloodRequest> get requests =>
      List.unmodifiable(SampleData.bloodRequests);
}
