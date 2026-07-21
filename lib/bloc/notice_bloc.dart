import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/notice_repository.dart';

part 'notice_event.dart';
part 'notice_state.dart';

class NoticeBloc extends Bloc<NoticeEvent, NoticeState> {
  NoticeBloc(NoticeRepository repository)
      : _repository = repository,
        super(const NoticeState(isLoading: true)) {
    on<NoticeStarted>(_onLoad);
    on<NoticeTabChanged>(_onTabChanged);
    on<NoticeRefreshRequested>(_onLoad);
  }

  final NoticeRepository _repository;

  void _onTabChanged(NoticeTabChanged event, Emitter<NoticeState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  Future<void> _onLoad(NoticeEvent event, Emitter<NoticeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final notices = await _repository.fetchNotices();
      emit(state.copyWith(notices: notices, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
