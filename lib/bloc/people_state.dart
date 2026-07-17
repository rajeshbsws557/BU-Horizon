part of 'people_bloc.dart';

class PeopleState extends Equatable {
  final String query;
  final List<Person> people;

  const PeopleState({this.query = '', this.people = const []});

  PeopleState copyWith({String? query, List<Person>? people}) =>
      PeopleState(query: query ?? this.query, people: people ?? this.people);

  @override
  List<Object?> get props => [query, people];
}
