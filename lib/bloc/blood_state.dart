part of 'blood_bloc.dart';

class BloodState extends Equatable {
  final int tab;
  final bool isLoading;
  final List<BloodRequest> requests;

  const BloodState({
    this.tab = 0,
    this.isLoading = false,
    this.requests = const [],
  });

  /// The most recent urgent open request, shown as the hero card.
  BloodRequest? get urgentNeed {
    for (final r in requests) {
      if (r.isUrgent) return r;
    }
    return null;
  }

  BloodState copyWith({int? tab, bool? isLoading, List<BloodRequest>? requests}) =>
      BloodState(
        tab: tab ?? this.tab,
        isLoading: isLoading ?? this.isLoading,
        requests: requests ?? this.requests,
      );

  @override
  List<Object?> get props => [tab, isLoading, requests];
}
