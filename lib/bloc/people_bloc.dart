import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/people_repository.dart';

part 'people_event.dart';
part 'people_state.dart';

class PeopleBloc extends Bloc<PeopleEvent, PeopleState> {
  PeopleBloc(this._repository) : super(const PeopleState(isLoading: true)) {
    on<PeopleSearched>(_onSearched);
    on<PeopleRefreshRequested>(_onRefreshRequested);
  }

  final PeopleRepository _repository;

  Future<void> _onSearched(PeopleSearched event, Emitter<PeopleState> emit) async {
    emit(state.copyWith(query: event.query, isLoading: true));
    try {
      final people = await _repository.search(event.query);
      emit(state.copyWith(people: people, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onRefreshRequested(
      PeopleRefreshRequested event, Emitter<PeopleState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final people = await _repository.search(state.query);
      emit(state.copyWith(people: people, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }
}
