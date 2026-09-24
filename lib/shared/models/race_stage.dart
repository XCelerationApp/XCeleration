import 'database/race.dart';

/// Where a race is, in the coach's words.
///
/// A race moves through six stored flow states, but a coach thinks of three
/// steps: set the race up, send it to the volunteers' phones, and collect the
/// results afterwards. Everything that shows a race's progress reads it from
/// here, so the words stay the same everywhere.
class RaceStage {
  const RaceStage._({
    required this.step,
    required this.label,
    required this.badge,
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

  bool get isFinished => step > steps.length;

  static RaceStage of(String? flowState) => switch (flowState) {
        Race.FLOW_SETUP => const RaceStage._(
            step: 1,
            label: 'Set up the race',
            badge: 'Setting Up',
            action: 'Finish Setup'),
        Race.FLOW_SETUP_COMPLETED => const RaceStage._(
            step: 2,
            label: 'Send to volunteers',
            badge: 'Ready to Send',
            action: 'Send to Volunteers'),
        Race.FLOW_PRE_RACE => const RaceStage._(
            step: 2,
            label: 'Sending to volunteers',
            badge: 'Sending',
            action: 'Send to Volunteers'),
        Race.FLOW_PRE_RACE_COMPLETED => const RaceStage._(
            step: 3,
            label: 'After the race, collect results',
            badge: 'Race Ready',
            action: 'Collect Results'),
        Race.FLOW_POST_RACE => const RaceStage._(
            step: 3,
            label: 'Collecting results',
            badge: 'Collecting Results',
            action: 'Collect Results'),
        Race.FLOW_FINISHED => const RaceStage._(
            step: 4, label: 'Race complete', badge: 'Race Complete'),
        _ => const RaceStage._(
            step: 1,
            label: 'Set up the race',
            badge: 'Setting Up',
            action: 'Finish Setup'),
      };
}
