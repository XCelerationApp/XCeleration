import 'package:flutter/material.dart';
import '../../../assistant/race_timer/screen/timing_screen.dart';
import '../../../assistant/bib_number_recorder/screen/bib_number_screen.dart';
import '../../../coach/races_screen/screen/races_screen.dart';

/// Enum representing the assistant roles in the app
enum Role {
  timer,
  bibRecorder,
  coach;

  String get displayName {
    switch (this) {
      case Role.timer:
        return 'Timer';
      case Role.bibRecorder:
        return 'Bib Recorder';
      case Role.coach:
        return 'Coach';
    }
  }

  String get description {
    switch (this) {
      case Role.timer:
        return 'Time a race';
      case Role.bibRecorder:
        return 'Record bib numbers';
      case Role.coach:
        return 'Manage races';
    }
  }

  IconData get icon {
    switch (this) {
      case Role.timer:
        return Icons.timer;
      case Role.bibRecorder:
        return Icons.numbers;
      case Role.coach:
        return Icons.person;
    }
  }

  Widget get screen {
    switch (this) {
      case Role.timer:
        return const TimingScreen();
      case Role.bibRecorder:
        return const BibNumberScreen();
      case Role.coach:
        return const RacesScreen();
    }
  }

  /// Convert from a string to enum value
  static Role? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'timer':
        return Role.timer;
      case 'bib recorder':
        return Role.bibRecorder;
      case 'coach':
        return Role.coach;
      default:
        return null;
    }
  }

  /// Convert to string representation
  String toValueString() {
    switch (this) {
      case Role.timer:
        return 'timer';
      case Role.bibRecorder:
        return 'bib recorder';
      case Role.coach:
        return 'coach';
    }
  }
}
