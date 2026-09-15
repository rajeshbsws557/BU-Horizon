import 'package:injectable/injectable.dart';

import '../data/sample_data.dart';
import '../models/models.dart';

/// Repository for class notices.
abstract interface class NoticeRepository {
  /// Existing university/batch notice feed used outside the course workflow.
  Future<List<ClassNotice>> fetchNotices();

  Future<List<ClassNotice>> fetchCourseNotices(String offeringId);

  Future<void> createCourseNotice({
    required String offeringId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
  });

  Future<void> updateCourseNotice({
    required String noticeId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
  });

  Future<void> deleteCourseNotice(String noticeId);
}

@Injectable(as: NoticeRepository)
final class SampleNoticeRepository implements NoticeRepository {
  late final Map<String, List<ClassNotice>> _courseNotices = {
    'offering-cse-1101': [
      for (final (index, notice) in SampleData.notices.take(3).indexed)
        notice.copyWith(
          id: 'sample-notice-$index',
          offeringId: 'offering-cse-1101',
          body: notice.subtitle,
        ),
    ],
    'offering-cse-1102': [
      SampleData.notices[5].copyWith(
        id: 'sample-notice-4',
        offeringId: 'offering-cse-1102',
        body: SampleData.notices[5].subtitle,
      ),
    ],
  };
  int _nextId = 10;

  @override
  Future<List<ClassNotice>> fetchNotices() async =>
      List.unmodifiable(SampleData.notices);

  @override
  Future<List<ClassNotice>> fetchCourseNotices(String offeringId) async =>
      List.unmodifiable(_courseNotices[offeringId] ?? const []);

  ClassNotice _notice({
    required String id,
    required String offeringId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
    ClassNotice? previous,
  }) {
    final style = SampleData.notices.firstWhere(
      (notice) => notice.category == category,
      orElse: () => SampleData.notices.first,
    );
    return ClassNotice(
      id: id,
      offeringId: offeringId,
      title: title,
      subtitle: body.split('\n').first,
      body: body,
      time: previous?.time ?? 'Just now',
      category: category,
      icon: style.icon,
      color: style.color,
      isPinned: isPinned,
    );
  }

  @override
  Future<void> createCourseNotice({
    required String offeringId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
  }) async {
    final items = _courseNotices.putIfAbsent(offeringId, () => []);
    items.insert(
      0,
      _notice(
        id: 'sample-notice-${_nextId++}',
        offeringId: offeringId,
        title: title,
        body: body,
        category: category,
        isPinned: isPinned,
      ),
    );
  }

  @override
  Future<void> updateCourseNotice({
    required String noticeId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
  }) async {
    for (final entry in _courseNotices.entries) {
      final index = entry.value.indexWhere((notice) => notice.id == noticeId);
      if (index == -1) continue;
      final current = entry.value[index];
      entry.value[index] = _notice(
        id: current.id,
        offeringId: current.offeringId,
        title: title,
        body: body,
        category: category,
        isPinned: isPinned,
        previous: current,
      );
      return;
    }
  }

  @override
  Future<void> deleteCourseNotice(String noticeId) async {
    for (final notices in _courseNotices.values) {
      notices.removeWhere((notice) => notice.id == noticeId);
    }
  }
}
