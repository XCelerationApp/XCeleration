import '../models/race_record.dart';
import '../services/demo_race_generator.dart';

/// The race to open when the app starts: the one the phone was working on.
///
/// Races are listed newest date first, and the app used to open the last one
/// in the list, the oldest (often the demo race). After a crash mid-race the
/// timer then reopened on the wrong race. Preference order:
/// 1. a race that is running (started and not stopped);
/// 2. the most recently started race;
/// 3. the real race with the newest date;
/// 4. anything (the demo race).
RaceRecord? raceToReopen(List<RaceRecord> races) {
  if (races.isEmpty) return null;
  final real = races.where((r) => !DemoRaceGenerator.isDemoRace(r)).toList();
  final candidates = real.isEmpty ? races : real;

  RaceRecord? latestStarted(Iterable<RaceRecord> list) {
    RaceRecord? best;
    for (final race in list) {
      if (race.startedAt == null) continue;
      if (best == null || race.startedAt!.isAfter(best.startedAt!)) {
        best = race;
      }
    }
    return best;
  }

  final running = latestStarted(candidates.where((r) => !r.stopped));
  if (running != null) return running;
  final started = latestStarted(candidates);
  if (started != null) return started;
  return candidates.reduce((a, b) => b.date.isAfter(a.date) ? b : a);
}
