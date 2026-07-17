import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for alerts / notifications.
abstract interface class AlertRepository {
  List<AlertItem> get alerts;
  List<AlertItem> busAlerts();
  List<AlertItem> noticeAlerts();
  List<AlertItem> otherAlerts();
}

@Injectable(as: AlertRepository)
final class SampleAlertRepository implements AlertRepository {
  @override
  List<AlertItem> get alerts => List.unmodifiable(SampleData.alerts);

  @override
  List<AlertItem> busAlerts() => List.unmodifiable(
        SampleData.alerts.where((a) => a.type == AlertType.bus),
      );

  @override
  List<AlertItem> noticeAlerts() => List.unmodifiable(
        SampleData.alerts.where(
          (a) => a.type == AlertType.notice || a.type == AlertType.exam,
        ),
      );

  @override
  List<AlertItem> otherAlerts() => List.unmodifiable(
        SampleData.alerts.where(
          (a) =>
              a.type == AlertType.event ||
              a.type == AlertType.library ||
              a.type == AlertType.lostFound,
        ),
      );
}
