part of 'blood_bloc.dart';

sealed class BloodEvent {
  const BloodEvent();
}

class BloodStarted extends BloodEvent {
  const BloodStarted();
}

class BloodTabChanged extends BloodEvent {
  final int tab;
  const BloodTabChanged(this.tab);
}

class BloodRefreshRequested extends BloodEvent {
  const BloodRefreshRequested();
}
