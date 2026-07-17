part of 'bus_bloc.dart';

sealed class BusEvent {
  const BusEvent();
}

class BusTabChanged extends BusEvent {
  final int tab;
  const BusTabChanged(this.tab);
}

class BusFavoriteToggled extends BusEvent {
  final String routeName;
  const BusFavoriteToggled(this.routeName);
}

class BusRefreshRequested extends BusEvent {
  const BusRefreshRequested();
}
