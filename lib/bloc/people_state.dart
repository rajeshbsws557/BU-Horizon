part of 'people_bloc.dart';

class PeopleState extends Equatable {
  final String query;
  final bool isLoading;
  final List<Person> people;

  const PeopleState({this.query = '', this.isLoading = false, this.people = const []});

  PeopleState copyWith({String? query, bool? isLoading, List<Person>? people}) =>
      PeopleState(
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
        people: people ?? this.people,
      );

  @override
  List<Object?> get props => [query, isLoading, people];
}
