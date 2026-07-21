part of 'notice_bloc.dart';

sealed class NoticeEvent {
  const NoticeEvent();
}

class NoticeStarted extends NoticeEvent {
  const NoticeStarted();
}

class NoticeTabChanged extends NoticeEvent {
  final int tab;
  const NoticeTabChanged(this.tab);
}

class NoticeRefreshRequested extends NoticeEvent {
  const NoticeRefreshRequested();
}
