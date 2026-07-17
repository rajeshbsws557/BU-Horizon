import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../repositories/bus_repository.dart';

part 'bus_event.dart';
part 'bus_state.dart';

class BusBloc extends Bloc<BusEvent, BusState> {
  BusBloc(this._repository) : super(BusState(routes: _repository.routes)) {
    on<BusTabChanged>(_onTabChanged);
    on<BusFavoriteToggled>(_onFavoriteToggled);
    on<BusRefreshRequested>(_onRefreshRequested);
    add(const BusRefreshRequested());
  }

  final BusRepository _repository;

  void _onTabChanged(BusTabChanged event, Emitter<BusState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  void _onFavoriteToggled(BusFavoriteToggled event, Emitter<BusState> emit) {
    _repository.toggleFavorite(event.routeName);
    emit(state.copyWith(routes: _repository.routes));
  }

  Future<void> _onRefreshRequested(
    BusRefreshRequested event,
    Emitter<BusState> emit,
  ) async {
    emit(state.copyWith(loading: true));
    await Future.delayed(const Duration(milliseconds: 450));
    if (isClosed) return;
    emit(state.copyWith(routes: _repository.routes, loading: false));
  }

}
