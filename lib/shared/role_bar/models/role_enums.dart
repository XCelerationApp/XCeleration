import 'package:flutter/material.dart';
import '../../../assistant/finish_line_roles/bib_recorder/screen/bib_recorder_v2_screen.dart';
import '../../../assistant/finish_line_roles/verifier/screen/verifier_screen.dart';
import '../../../assistant/finish_line_roles/fixer/screen/fixer_screen.dart';
import '../../../assistant/race_timer/screen/timing_screen.dart';
import '../../../assistant/bib_number_recorder/screen/bib_number_screen.dart';
import '../../../assistant/bib_number_recorder/controller/bib_number_controller.dart';
import '../../../assistant/shared/services/assistant_storage_service.dart';
import '../../../assistant/shared/services/demo_race_generator_impl.dart';
import '../../../core/services/device_connection_factory_impl.dart';
import '../../../core/services/post_frame_scheduler.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../coach/races_screen/screen/races_screen.dart';
import '../../../spectator/races_screen/screen/spectator_races_screen.dart';

/// Enum representing the assistant roles in the app
enum Role {
  timer,
  bibRecorder,
  bibRecorderV2,
  verifier,
  fixer,
  coach,
  spectator;

  String get displayName {
    switch (this) {
      case Role.timer:
        return 'Timer';
      case Role.bibRecorder:
        return 'Bib Recorder';
      case Role.bibRecorderV2:
        return 'Bib Recorder (New)';
      case Role.verifier:
        return 'Verifier';
      case Role.fixer:
        return 'Fixer';
      case Role.coach:
        return 'Coach';
      case Role.spectator:
        return 'Spectator';
    }
  }

  String get description {
    switch (this) {
      case Role.timer:
        return 'Time a race';
      case Role.bibRecorder:
        return 'Record bib numbers';
      case Role.bibRecorderV2:
        return 'Record bib numbers (new UI)';
      case Role.verifier:
        return 'Confirm runner names at chute exit';
      case Role.fixer:
        return 'Resolve flagged bib conflicts';
      case Role.coach:
        return 'Manage races';
      case Role.spectator:
        return 'View coach races (read-only)';
    }
  }

  IconData get icon {
    switch (this) {
      case Role.timer:
        return Icons.timer;
      case Role.bibRecorder:
        return Icons.numbers;
      case Role.bibRecorderV2:
        return Icons.mic;
      case Role.verifier:
        return Icons.check_circle_outline;
      case Role.fixer:
        return Icons.build_circle_outlined;
      case Role.coach:
        return Icons.person;
      case Role.spectator:
        return Icons.visibility;
    }
  }

  Widget get screen {
    switch (this) {
      case Role.timer:
        return const TimingScreen();
      case Role.bibRecorder:
        return BibNumberScreen(
          controller: BibNumberController(
            storage: AssistantStorageService.instance,
            tutorialManager: TutorialManager(),
            demoRaceGenerator: const DemoRaceGeneratorImpl(),
            deviceConnectionFactory: const DeviceConnectionFactoryImpl(),
            scheduler: const PostFrameScheduler(),
          ),
        );
      case Role.bibRecorderV2:
        return BibRecorderV2Screen(storage: AssistantStorageService.instance);
      case Role.verifier:
        return VerifierScreen(storage: AssistantStorageService.instance);
      case Role.fixer:
        return FixerScreen(storage: AssistantStorageService.instance);
      case Role.coach:
        return const RacesScreen();
      case Role.spectator:
        return const SpectatorRacesScreen();
    }
  }

  /// Convert from a string to enum value
  static Role? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'timer':
        return Role.timer;
      case 'bib recorder':
        return Role.bibRecorder;
      case 'bib recorder (new)':
        return Role.bibRecorderV2;
      case 'verifier':
        return Role.verifier;
      case 'fixer':
        return Role.fixer;
      case 'coach':
        return Role.coach;
      case 'spectator':
        return Role.spectator;
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
      case Role.bibRecorderV2:
        return 'bib recorder (new)';
      case Role.verifier:
        return 'verifier';
      case Role.fixer:
        return 'fixer';
      case Role.coach:
        return 'coach';
      case Role.spectator:
        return 'spectator';
    }
  }
}
