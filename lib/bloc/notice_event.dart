part of 'notice_bloc.dart';

sealed class NoticeEvent {
  const NoticeEvent();
}

class NoticeTabChanged extends NoticeEvent {
  final int tab;
  const NoticeTabChanged(this.tab);
}

class NoticeRefreshRequested extends NoticeEvent {
  const NoticeRefreshRequested();
}
