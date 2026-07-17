import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for class notices.
abstract interface class NoticeRepository {
  List<ClassNotice> get notices;
  List<ClassNotice> byCategory(NoticeCategory category);
}

@Injectable(as: NoticeRepository)
final class SampleNoticeRepository implements NoticeRepository {
  @override
  List<ClassNotice> get notices =>
      List.unmodifiable(SampleData.notices);

  @override
  List<ClassNotice> byCategory(NoticeCategory category) =>
      List.unmodifiable(
        SampleData.notices.where((n) => n.category == category),
      );
}
