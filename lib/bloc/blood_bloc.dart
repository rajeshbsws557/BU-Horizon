import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/blood_repository.dart';

part 'blood_event.dart';
part 'blood_state.dart';

class BloodBloc extends Bloc<BloodEvent, BloodState> {
  BloodBloc(BloodRepository repository)
      : _repository = repository,
        super(const BloodState(isLoading: true)) {
    on<BloodStarted>(_onLoad);
    on<BloodTabChanged>(_onTabChanged);
    on<BloodRefreshRequested>(_onLoad);
  }

  final BloodRepository _repository;

  void _onTabChanged(BloodTabChanged event, Emitter<BloodState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  Future<void> _onLoad(BloodEvent event, Emitter<BloodState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final requests = await _repository.fetchRequests();
      emit(state.copyWith(requests: requests, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
