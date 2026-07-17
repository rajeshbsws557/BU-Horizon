part of 'people_bloc.dart';

sealed class PeopleEvent {
  const PeopleEvent();
}

class PeopleSearched extends PeopleEvent {
  final String query;
  const PeopleSearched(this.query);
}

class PeopleRefreshRequested extends PeopleEvent {
  const PeopleRefreshRequested();
}
