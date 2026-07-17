part of 'notice_bloc.dart';

class NoticeState extends Equatable {
  final int tab;
  final List<ClassNotice> notices;

  const NoticeState({this.tab = 0, this.notices = const []});

  NoticeState copyWith({int? tab, List<ClassNotice>? notices}) =>
      NoticeState(tab: tab ?? this.tab, notices: notices ?? this.notices);

  List<ClassNotice> get visibleNotices {
    switch (tab) {
      case 1:
        return notices.where((n) => n.category == NoticeCategory.academic).toList();
      case 2:
        return notices.where((n) => n.category == NoticeCategory.events).toList();
      case 3:
        return notices.where((n) => n.category == NoticeCategory.department).toList();
      default:
        return notices;
    }
  }

  @override
  List<Object?> get props => [tab, notices];
}
