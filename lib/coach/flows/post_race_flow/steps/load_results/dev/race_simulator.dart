import 'dart:math';

import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

/// Debug builds only: stands in for the Timer and Bib Recorder so the whole
/// coach flow can be tested on one device. The data is encoded exactly as the
/// devices send it, so loading, conflicts and saving run the real code; only
/// the wireless transfer is skipped.

/// Which mistakes the simulated devices make.
enum SimulatedScenario {
  clean('Clean race', 'No mistakes.'),
  missingTime('Missing time',
      'The Timer missed a runner and pressed "missing time".'),
  extraTime(
      'Extra time', 'The Timer tapped twice and pressed "extra time".'),
  timerMissedRunner('Timer missed a runner (no button)',
      'A finisher after the last confirmation got no time, and the Timer '
          'did not notice.'),
  strayTap('Stray tap (no button)',
      'An extra time after the last confirmation, and the Timer did not '
          'notice.'),
  bibTypo('Mistyped bib', 'The Bib Recorder mistyped one bib number.'),
  bibCollision('Bib typed as another runner',
      "The Bib Recorder typed one runner's bib as another runner's, so that "
          'bib appears at two finishes.'),
  everything('Everything at once',
      'Missing time, extra time, a runner the Timer missed, a mistyped bib '
          "and a bib typed as another runner's.");

  const SimulatedScenario(this.label, this.description);
  final String label;
  final String description;
}

/// One finisher in the answer key.
class SimulatedFinisher {
  final int place;
  final RaceRunner runner;
  final String time;

  const SimulatedFinisher(this.place, this.runner, this.time);
}

class SimulatedRace {
  /// What the Bib Recorder would send.
  final String bibData;

  /// What the Timer would send.
  final String timingData;

  /// The true finish order and times: what the saved results should be.
  final List<SimulatedFinisher> answerKey;

  /// Each mistake that was made and how the coach should resolve it.
  final List<String> notes;

  const SimulatedRace({
    required this.bibData,
    required this.timingData,
    required this.answerKey,
    required this.notes,
  });
}

class RaceSimulator {
  RaceSimulator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const minimumRunners = 8;

  /// Simulates a race run by [runners] (in random order). Throws
  /// [StateError] if there are fewer than [minimumRunners] with bibs.
  Future<SimulatedRace> simulate(
      List<RaceRunner> runners, SimulatedScenario scenario) async {
    final finishers = runners
        .where((r) => (r.runner.bibNumber ?? '').isNotEmpty)
        .toList()
      ..shuffle(_random);
    if (finishers.length < minimumRunners) {
      throw StateError('Add at least $minimumRunners runners with bib '
          'numbers to simulate a race.');
    }

    final all = scenario == SimulatedScenario.everything;
    bool has(SimulatedScenario s) => all || scenario == s;
    final notes = <String>[];

    // True finish times: from 15:00, 0.4 to 6 seconds apart, in hundredths.
    var centis = 15 * 60 * 100;
    final times = <Duration>[];
    for (var i = 0; i < finishers.length; i++) {
      centis += 40 + _random.nextInt(560);
      times.add(Duration(milliseconds: centis * 10));
    }
    String fmt(Duration d) => TimeFormatter.formatDuration(d);

    final answerKey = [
      for (var i = 0; i < finishers.length; i++)
        SimulatedFinisher(i + 1, finishers[i], fmt(times[i]))
    ];

    // Split the finishers into chunks of 4 to 6, each ended by a button.
    final groups = <List<int>>[];
    var start = 0;
    while (start < finishers.length) {
      var size = 4 + _random.nextInt(3);
      if (finishers.length - (start + size) < 3) {
        size = finishers.length - start; // fold a short tail into this one
      }
      groups.add([for (var i = start; i < start + size; i++) i]);
      start += size;
    }
    final last = groups.length - 1;
    final missingGroup = groups.length > 2 ? 1 : 0;
    final extraGroup = groups.length > 2 ? 2 : last;

    String describe(int i) =>
        '${finishers[i].runner.name} (bib ${finishers[i].runner.bibNumber}, '
        'place ${i + 1})';

    final records = <TimingDatum>[];
    for (var g = 0; g < groups.length; g++) {
      final group = groups[g];
      final groupTimes = [for (final i in group) times[i]];
      final buttonAt = groupTimes.last + const Duration(seconds: 1);
      var conflict = Conflict(type: ConflictType.confirmRunner);

      if (has(SimulatedScenario.missingTime) && g == missingGroup) {
        final k = _random.nextInt(group.length);
        groupTimes.removeAt(k);
        conflict = Conflict(type: ConflictType.missingTime);
        notes.add('Missing time: the Timer missed ${describe(group[k])}. '
            'Move the TBD to place ${group[k] + 1} and enter '
            '${fmt(times[group[k]])}.');
      }
      if (has(SimulatedScenario.extraTime) && g == extraGroup &&
          !(has(SimulatedScenario.missingTime) && g == missingGroup)) {
        final k = 1 + _random.nextInt(groupTimes.length - 1);
        final stray = groupTimes[k - 1] + (groupTimes[k] - groupTimes[k - 1]) ~/ 2;
        groupTimes.insert(k, _hundredths(stray));
        conflict = Conflict(type: ConflictType.extraTime);
        notes.add('Extra time: ${fmt(groupTimes[k])} was a stray tap. '
            'Remove it.');
      }
      if (g == last) {
        if (has(SimulatedScenario.timerMissedRunner)) {
          // A finisher whose time is still there (not already missing).
          final candidates =
              group.where((i) => groupTimes.contains(times[i])).toList();
          final i = candidates[_random.nextInt(candidates.length)];
          groupTimes.remove(times[i]);
          notes.add('The Timer missed ${describe(i)} without noticing. The '
              'coach sees a missing time in the last group: move the TBD to '
              'place ${i + 1} and enter ${fmt(times[i])}.');
        } else if (has(SimulatedScenario.strayTap)) {
          final stray = _hundredths(groupTimes.last +
              (buttonAt - groupTimes.last) ~/ 2);
          groupTimes.add(stray);
          notes.add('Stray tap: ${fmt(stray)} at the end is not a runner. '
              'Remove it.');
        }
        // A stopped Timer closes the race with a checkpoint, unless the last
        // chunk already ends with a conflict.
      }

      records.addAll(groupTimes.map((t) => TimingDatum(time: fmt(t))));
      records.add(TimingDatum(time: fmt(buttonAt), conflict: conflict));
    }

    // Bib Recorder: every finisher in order, with its mistakes.
    final bibs = [for (final r in finishers) BibDatum.fromRaceRunner(r)];
    final taken = {for (final r in runners) r.runner.bibNumber};
    // Two runners whose entries are left alone, so each mistake stays legible.
    final untouched = <int>{};
    if (has(SimulatedScenario.bibCollision)) {
      // One runner's bib typed as another's. Both finishes are real people:
      // the count still matches, and the coach has to say which finish
      // belongs to the runner whose bib it is.
      final owner = _random.nextInt(finishers.length);
      var mistyped = _random.nextInt(finishers.length);
      while (mistyped == owner) {
        mistyped = _random.nextInt(finishers.length);
      }
      final bib = finishers[owner].runner.bibNumber!;
      bibs[mistyped] = BibDatum(bib: bib);
      untouched..add(owner)..add(mistyped);
      final first = owner < mistyped ? owner : mistyped;
      final second = owner < mistyped ? mistyped : owner;
      notes.add('Bib typed as another runner: #$bib is at places '
          '${first + 1} and ${second + 1}. Place ${owner + 1} is '
          '${describe(owner)}, whose bib it is. The other finish is really '
          '${describe(mistyped)} — choose them as the existing runner.');
    }
    if (has(SimulatedScenario.bibTypo)) {
      // Not a runner the collision already touched, or one mistake would
      // swallow the other.
      var k = _random.nextInt(finishers.length);
      while (untouched.contains(k)) {
        k = _random.nextInt(finishers.length);
      }
      final real = finishers[k].runner.bibNumber!;
      var typo = '${real}7';
      while (taken.contains(typo)) {
        typo = '${typo}7';
      }
      final index = bibs.indexWhere((b) => b.bib == real);
      bibs[index] = BibDatum(bib: typo);
      notes.add('Mistyped bib: $typo is really ${describe(k)}. Choose them '
          'as the existing runner.');
    }
    if (notes.isEmpty) notes.add('No mistakes: everything should match.');

    return SimulatedRace(
      bibData: await BibEncodeUtils.getEncodedBibData(bibs),
      timingData: await TimingEncodeUtils.encodeTimeRecords(records),
      answerKey: answerKey,
      notes: notes,
    );
  }

  static Duration _hundredths(Duration d) =>
      Duration(milliseconds: (d.inMilliseconds / 10).round() * 10);
}
