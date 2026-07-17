import 'package:bu_horizon/bloc/blood_bloc.dart';
import 'package:bu_horizon/bloc/bus_bloc.dart';
import 'package:bu_horizon/bloc/notice_bloc.dart';
import 'package:bu_horizon/bloc/people_bloc.dart';
import 'package:bu_horizon/models/models.dart';
import 'package:bu_horizon/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBusRepository extends Mock implements BusRepository {}

class MockNoticeRepository extends Mock implements NoticeRepository {}

class MockPeopleRepository extends Mock implements PeopleRepository {}

class MockBloodRepository extends Mock implements BloodRepository {}

void main() {
  group('BusBloc', () {
    late MockBusRepository repo;
    late BusBloc bloc;

    setUp(() {
      repo = MockBusRepository();
      when(() => repo.routes).thenReturn([
        const BusRoute(
          name: 'Mirpur Route',
          window: '7:30 AM - 10:30 PM',
          frequency: 'Every 20 min',
          nextBus: '9:30 AM',
          favorite: true,
        ),
        const BusRoute(
          name: 'Uttara Route',
          window: '7:00 AM - 10:00 PM',
          frequency: 'Every 25 min',
          nextBus: '9:25 AM',
        ),
      ]);
      bloc = BusBloc(repo);
    });

    tearDown(() => bloc.close());

    test('initial state uses repository routes', () {
      expect(bloc.state.routes.length, 2);
    });

    test('tab change updates tab index', () async {
      bloc.add(const BusTabChanged(2));
      await expectState<BusState>(bloc, (s) => s.tab == 2);
    });

    test('favorite toggle delegates to repository and emits updated routes', () async {
      when(() => repo.toggleFavorite('Mirpur Route')).thenAnswer((_) {});
      when(() => repo.routes).thenReturn([
        const BusRoute(
          name: 'Mirpur Route',
          window: '7:30 AM - 10:30 PM',
          frequency: 'Every 20 min',
          nextBus: '9:30 AM',
        ),
        const BusRoute(
          name: 'Uttara Route',
          window: '7:00 AM - 10:00 PM',
          frequency: 'Every 25 min',
          nextBus: '9:25 AM',
        ),
      ]);

      bloc.add(const BusFavoriteToggled('Mirpur Route'));
      await expectState<BusState>(bloc, (s) => !s.routes.first.favorite);
      verify(() => repo.toggleFavorite('Mirpur Route')).called(1);
    });
  });

  group('NoticeBloc', () {
    late MockNoticeRepository repo;
    late NoticeBloc bloc;

    setUp(() {
      repo = MockNoticeRepository();
      when(() => repo.notices).thenReturn([
        const ClassNotice(
          title: 'Exam Notice',
          subtitle: 'Midterm exam routine published',
          time: 'Yesterday',
          category: NoticeCategory.academic,
          icon: Icons.edit_document,
          color: Colors.orange,
        ),
      ]);
      bloc = NoticeBloc(repo);
    });

    tearDown(() => bloc.close());

    test('initial state loads notices from repository', () {
      expect(bloc.state.notices.length, 1);
    });

    test('tab change updates tab index', () async {
      bloc.add(const NoticeTabChanged(1));
      await expectState<NoticeState>(bloc, (s) => s.tab == 1);
    });
  });

  group('PeopleBloc', () {
    late MockPeopleRepository repo;
    late PeopleBloc bloc;

    setUp(() {
      repo = MockPeopleRepository();
      when(() => repo.search(any())).thenReturn([
        const Person(name: 'Nusrat Jahan', department: 'CSE Department', email: 'nusrat@bu.edu.bd'),
      ]);
      bloc = PeopleBloc(repo);
    });

    tearDown(() => bloc.close());

    test('search updates query and people', () async {
      bloc.add(const PeopleSearched('nusrat'));
      await expectState<PeopleState>(bloc, (s) => s.query == 'nusrat' && s.people.length == 1);
      verify(() => repo.search('nusrat')).called(1);
    });

    test('empty query returns repository results', () async {
      bloc.add(const PeopleSearched(''));
      await expectState<PeopleState>(bloc, (s) => s.query.isEmpty && s.people.length == 1);
      verify(() => repo.search('')).called(1);
    });
  });

  group('BloodBloc', () {
    late MockBloodRepository repo;
    late BloodBloc bloc;

    setUp(() {
      repo = MockBloodRepository();
      when(() => repo.urgentNeed).thenReturn(
        const BloodNeed(
          units: 3,
          group: BloodGroup.bPositive,
          contact: '01712-345678',
          location: 'Shaheed Suhrawardy Medical',
          time: '2 hrs ago',
        ),
      );
      when(() => repo.requests).thenReturn([
        const BloodRequest(group: BloodGroup.oNegative, location: 'Ibrahim Medical', time: '3 hrs ago'),
      ]);
      bloc = BloodBloc(repo);
    });

    tearDown(() => bloc.close());

    test('initial state loads urgent need and requests', () {
      expect(bloc.state.urgentNeed.group, BloodGroup.bPositive);
      expect(bloc.state.requests.length, 1);
    });

    test('tab change updates tab index', () async {
      bloc.add(const BloodTabChanged(1));
      await expectState<BloodState>(bloc, (s) => s.tab == 1);
    });
  });
}

Future<void> expectState<S>(BlocBase<S> bloc, bool Function(S) predicate) async {
  await bloc.stream.firstWhere(predicate);
}
