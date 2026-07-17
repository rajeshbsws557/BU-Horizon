import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/notice_repository.dart';

part 'notice_event.dart';
part 'notice_state.dart';

class NoticeBloc extends Bloc<NoticeEvent, NoticeState> {
  NoticeBloc(NoticeRepository repository)
      : _repository = repository,
        super(NoticeState(notices: repository.notices)) {
    on<NoticeTabChanged>(_onTabChanged);
    on<NoticeRefreshRequested>(_onRefreshRequested);
  }

  final NoticeRepository _repository;

  void _onTabChanged(NoticeTabChanged event, Emitter<NoticeState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  void _onRefreshRequested(NoticeRefreshRequested event, Emitter<NoticeState> emit) {
    emit(state.copyWith(notices: _repository.notices));
  }
}
