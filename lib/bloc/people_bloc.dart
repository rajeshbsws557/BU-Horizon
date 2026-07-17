import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/people_repository.dart';

part 'people_event.dart';
part 'people_state.dart';

class PeopleBloc extends Bloc<PeopleEvent, PeopleState> {
  PeopleBloc(this._repository) : super(const PeopleState()) {
    on<PeopleSearched>(_onSearched);
    on<PeopleRefreshRequested>(_onRefreshRequested);
  }

  final PeopleRepository _repository;

  void _onSearched(PeopleSearched event, Emitter<PeopleState> emit) {
    emit(state.copyWith(query: event.query, people: _repository.search(event.query)));
  }

  void _onRefreshRequested(PeopleRefreshRequested event, Emitter<PeopleState> emit) {
    emit(state.copyWith(people: _repository.search(state.query)));
  }
}
