part of 'bus_bloc.dart';

class BusState extends Equatable {
  final int tab;
  final List<BusRoute> routes;
  final bool loading;

  const BusState({this.tab = 0, this.routes = const [], this.loading = true});

  BusState copyWith({int? tab, List<BusRoute>? routes, bool? loading}) =>
      BusState(
        tab: tab ?? this.tab,
        routes: routes ?? this.routes,
        loading: loading ?? this.loading,
      );

  List<BusRoute> get visibleRoutes {
    switch (tab) {
      case 2:
        return routes.where((r) => r.favorite).toList();
      case 1:
        return routes.take(3).toList();
      default:
        return routes;
    }
  }

  @override
  List<Object?> get props => [tab, routes, loading];
}
