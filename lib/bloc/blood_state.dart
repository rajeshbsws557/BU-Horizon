part of 'blood_bloc.dart';

class BloodState extends Equatable {
  final int tab;
  final BloodNeed urgentNeed;
  final List<BloodRequest> requests;

  const BloodState({
    this.tab = 0,
    required this.urgentNeed,
    this.requests = const [],
  });

  BloodState copyWith({int? tab, BloodNeed? urgentNeed, List<BloodRequest>? requests}) =>
      BloodState(
        tab: tab ?? this.tab,
        urgentNeed: urgentNeed ?? this.urgentNeed,
        requests: requests ?? this.requests,
      );

  @override
  List<Object?> get props => [tab, urgentNeed, requests];
}
