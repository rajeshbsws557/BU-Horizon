import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/blood_repository.dart';

part 'blood_event.dart';
part 'blood_state.dart';

class BloodBloc extends Bloc<BloodEvent, BloodState> {
  BloodBloc(BloodRepository repository)
      : _repository = repository,
        super(BloodState(
          urgentNeed: repository.urgentNeed,
          requests: repository.requests,
        )) {
    on<BloodTabChanged>(_onTabChanged);
    on<BloodRefreshRequested>(_onRefreshRequested);
  }

  final BloodRepository _repository;

  void _onTabChanged(BloodTabChanged event, Emitter<BloodState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  void _onRefreshRequested(BloodRefreshRequested event, Emitter<BloodState> emit) {
    emit(state.copyWith(
      urgentNeed: _repository.urgentNeed,
      requests: _repository.requests,
    ));
  }
}
