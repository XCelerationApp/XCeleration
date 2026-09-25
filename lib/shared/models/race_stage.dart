import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'database/race.dart';

/// Where a race is, in the coach's words.
///
/// A race moves through six stored flow states, but a coach thinks of three
/// steps: set the race up, send it to the volunteers' phones, and collect the
/// results afterwards. Everything that shows a race's progress reads it from
/// here, so the words and colours stay the same everywhere.
///
/// The colour says where the coach is: yellow before race day (including
/// once setup is done), blue from sending the race to the volunteers until
/// it is run, purple while collecting results, green when done. The race
/// only moves on to step 2 once it has actually been sent.
class RaceStage {
  const RaceStage._({
    required this.step,
    required this.label,
    required this.badge,
    required this.color,
    this.action,
  });

  /// The three steps, in order, as the progress bar names them.
  static const steps = ['Set up', 'Send to volunteers', 'Collect results'];

  /// 1 to 3 while the race is under way; 4 once it is finished.
  final int step;

  /// What the race header says the coach is on, such as 'Send to volunteers'.
  final String label;

  /// The short status on a race's card in the races list.
  final String badge;

  /// What the header button does next, or null once the race is finished.
  final String? action;

  /// The stage's colour, for the header, steps bar and badges.
  final Color color;

  bool get isFinished => step > steps.length;

  static RaceStage of(String? flowState) => switch (flowState) {
        Race.FLOW_SETUP => _settingUp,
        Race.FLOW_SETUP_COMPLETED => const RaceStage._(
            step: 1,
            label: 'Ready to send to volunteers',
            badge: 'Ready to Send',
            color: AppColors.statusSetup,
            action: 'Send to Volunteers'),
        Race.FLOW_PRE_RACE => const RaceStage._(
            step: 2,
            label: 'Sending to volunteers',
            badge: 'Sending',
            color: AppColors.statusPreRace,
            action: 'Send to Volunteers'),
        Race.FLOW_PRE_RACE_COMPLETED => const RaceStage._(
            step: 2,
            label: 'Sent. After the race, collect results',
            badge: 'Race Ready',
            color: AppColors.statusPreRace,
            action: 'Collect Results'),
        Race.FLOW_POST_RACE => const RaceStage._(
            step: 3,
            label: 'Collecting results',
            badge: 'Collecting Results',
            color: AppColors.statusPostRace,
            action: 'Collect Results'),
        Race.FLOW_FINISHED => const RaceStage._(
            step: 4,
            label: 'Race complete',
            badge: 'Race Complete',
            color: AppColors.statusFinished),
        _ => _settingUp,
      };

  static const _settingUp = RaceStage._(
      step: 1,
      label: 'Set up the race',
      badge: 'Setting Up',
      color: AppColors.statusSetup,
      action: 'Finish Setup');
}
