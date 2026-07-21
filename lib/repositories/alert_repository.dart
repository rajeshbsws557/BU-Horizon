import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for alerts / notifications.
abstract interface class AlertRepository {
  Future<List<AlertItem>> fetchAlerts();
}

@Injectable(as: AlertRepository)
final class SampleAlertRepository implements AlertRepository {
  @override
  Future<List<AlertItem>> fetchAlerts() async =>
      List.unmodifiable(SampleData.alerts);
}
