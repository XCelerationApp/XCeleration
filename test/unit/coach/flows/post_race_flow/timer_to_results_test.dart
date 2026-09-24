import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/assistant/race_timer/controller/timing_controller.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/coach/flows/post_race_flow/steps/load_results/controller/load_results_controller.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

import '../../../assistant/race_timer/controller/timing_controller_test.mocks.dart';
import 'load_results_controller_test.mocks.dart';

// The whole chain, for any mix of confirmations, missing times and extra
// times: the real Timer model records the race, shares it the way the device
// does, the coach loads it, resolves every conflict the way a coach would,
// and saves. The saved results must be exactly the true finish order and
// times.
//
// Conflicts stack: pressing "missing time" (or "extra time") twice in a row
// makes one conflict covering two finishers, so these tests cover counts
// above one, several conflicts in a chunk's span, and conflicts that cancel.

class _NoopScheduler implements IPostFrameCallbackScheduler {
  @override
  void addPostFrameCallback(VoidCallback callback) {}
}

const _teams = [
  Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG'),
  Team(teamId: 2, name: 'Hawks', abbreviation: 'HAW'),
  Team(teamId: 3, name: 'Owls', abbreviation: 'OWL'),
];

RaceRunner _runner(int i) => RaceRunner(
      raceId: 1,
      runner: Runner(
          runnerId: i, name: 'Runner $i', bibNumber: '${100 + i}', grade: 10),
      team: _teams[i % 3],
    );

/// What the Timer does at the finish line, one button at a time.
sealed class _Press {
  const _Press();
}

/// A finisher crosses the line. [logged] false means the Timer missed them.
class _Finish extends _Press {
  const _Finish({this.logged = true});
  final bool logged;
}

/// A tap that was not a finisher.
class _Stray extends _Press {
  const _Stray();
}

class _Confirm extends _Press {
  const _Confirm();
}

class _MissingTime extends _Press {
  const _MissingTime();
}

class _ExtraTime extends _Press {
  const _ExtraTime();
}

/// Takes back one conflict press, as deleting the last record does.
class _Undo extends _Press {
  const _Undo();
}

/// Runs [presses] through the real Timer — the controller, so its own rules
/// about which presses are allowed apply — and returns what it would share.
/// Returns null when the sequence was refused in a way that makes the race
/// meaningless to check.
Future<String> _runTimer(List<_Press> presses, List<Duration> times) async {
  final storage = MockIAssistantStorageService();
  when(storage.updateRaceStatus(any, any, any))
      .thenAnswer((_) async => const Success(null));
  when(storage.updateRaceStartTime(any, any, any))
      .thenAnswer((_) async => const Success(null));
  when(storage.updateRaceDuration(any, any, any))
      .thenAnswer((_) async => const Success(null));
  when(storage.saveChunk(any, any)).thenAnswer((_) async => const Success(null));
  when(storage.deleteChunk(any, any))
      .thenAnswer((_) async => const Success(null));
  when(storage.getRaces(any)).thenAnswer((_) async => const Success([]));
  final haptics = MockIHapticFeedback();
  when(haptics.vibrate()).thenAnswer((_) async {});
  when(haptics.lightImpact()).thenAnswer((_) async {});

  // A clock the test moves on by hand, so times are exactly the ones the
  // answer key expects.
  var elapsed = Duration.zero;
  final start = DateTime(2026, 9, 22, 10);
  final timing = TimingController(
    storage: storage,
    hapticFeedback: haptics,
    now: () => start.add(elapsed),
    monotonic: () => elapsed,
  );
  timing.currentRace = RaceRecord(
    raceId: 1,
    date: DateTime(2026, 9, 22),
    name: 'Property',
    type: DeviceName.raceTimer.toString(),
    stopped: true,
  );
  timing.startRace();

  var finisher = 0;
  void tick() => elapsed += const Duration(milliseconds: 200);

  for (final press in presses) {
    switch (press) {
      case _Finish(:final logged):
        elapsed = times[finisher++];
        if (logged) timing.logTime();
      case _Stray():
        tick();
        timing.logTime();
      case _Confirm():
        tick();
        timing.confirmTimes();
      case _MissingTime():
        tick();
        await timing.addMissingTime();
      case _ExtraTime():
        tick();
        // A refusal (nothing to remove) is a no-op, exactly as on the device.
        // When every time in the batch would be extra the device asks first;
        // the tester says yes.
        final result = await timing.removeExtraTime();
        if (result is RemoveExtraTimeConfirmRequired) {
          timing.executeRemoveExtraTimeDeletion();
        }
      case _Undo():
        // Takes back the last press only, as deleting the last record does;
        // undoing a whole stacked conflict is a different action.
        if (timing.currentChunk.hasConflict) {
          timing.reduceCurrentConflictByOne();
        }
    }
  }
  tick();
  timing.stopRace();
  final shared = await timing.encodedRecords();
  timing.dispose();
  return shared;
}

String fmt(Duration d) => TimeFormatter.formatDuration(d);

String _describe(List<_Press> presses) => presses
    .map((p) => switch (p) {
          _Finish(:final logged) => logged ? 'finish' : 'MISSED',
          _Stray() => 'stray',
          _Confirm() => 'CONFIRM',
          _MissingTime() => 'missing',
          _ExtraTime() => 'extra',
          _Undo() => 'undo',
        })
    .join(' ');

UIChunk? _ui(MergeConflictsController c, int id) =>
    c.uiChunks.where((u) => u.chunkId == id).firstOrNull;

String _state(MergeConflictsController c) =>
    'chunks: ${c.timingChunks.map((t) => '#${t.id} "${t.encode()}" '
        '(${t.conflictRecord?.conflict?.type}, offBy '
        '${t.conflictRecord?.conflict?.offBy}, count ${t.recordCount})').join(' | ')}\n'
    'rows shown: ${c.uiChunks.map((u) => '#${u.chunkId} ${u.times}').join(' | ')}';

/// Resolves every conflict using only what the screen shows, plus the true
/// times (which a coach would have from a backup watch).
Future<void> _resolve(MergeConflictsController c, List<String> truth) async {
  final truthSet = truth.toSet();
  for (var round = 0; round < 60 && c.hasConflicts; round++) {
    final visible = c.uiChunks
        .where((u) => u.conflict.type != ConflictType.confirmRunner)
        .toList();
    if (visible.isEmpty) {
      fail('a conflict the screen never shows\n${_state(c)}');
    }
    final id = visible.first.chunkId;
    final ui = _ui(c, id);
    if (ui == null) continue;

    if (ui.conflict.type == ConflictType.extraTime) {
      // Remove each time that was not a finisher. The batch can close (and
      // merge into the confirmed times) as soon as the last one goes.
      final rows = ui.records.length;
      for (var guard = 0; guard <= rows; guard++) {
        final current = _ui(c, id);
        if (current == null) break;
        final stray =
            current.records.indexWhere((r) => !truthSet.contains(r.time));
        if (stray == -1) break;
        if (!c.removeExtraTime(id, stray)) break;
      }
      if (_ui(c, id) != null) await c.resolveExtraTimeConflict(id);
    } else {
      final start = ui.startingPlace - 1;
      final expected = truth.sublist(start, start + ui.records.length);
      // Put an empty slot in front of every recorded time that has slipped
      // to the wrong place, then fill the empty slots in.
      for (var j = 0; j < expected.length; j++) {
        final current = _ui(c, id);
        if (current == null) break;
        if (!current.records[j].isUnfilled &&
            current.records[j].time != expected[j]) {
          c.insertTbdAt(id, j);
        }
      }
      final filled = _ui(c, id);
      if (filled != null) {
        for (var j = 0; j < expected.length; j++) {
          if (filled.records[j].isUnfilled) {
            c.updateMissingTimeRecord(id, j, expected[j]);
          }
        }
        await c.resolveMissingTimeConflict(id);
      }
    }

    // Still unresolved after a full attempt: say why rather than spinning.
    final after = _ui(c, id);
    if (after != null && after.conflict.type != ConflictType.confirmRunner) {
      final wanted = truth.sublist(after.startingPlace - 1,
          after.startingPlace - 1 + after.records.length);
      fail('stuck on chunk $id (${after.conflict.type}, offBy '
          '${after.conflict.offBy}, starts at place ${after.startingPlace})\n'
          'rows: ${after.records.map((r) => '${r.place}:${r.time}'
              '${r.validationError == null ? '' : '!${r.validationError}'}').join(', ')}\n'
          'wanted: ${wanted.join(', ')}\n${_state(c)}');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    provideDummy(TimingDatum(time: '0:00.00'));
    provideDummy<Result<void>>(const Success(null));
    provideDummy<Result<List<RaceRecord>>>(const Success([]));
    provideDummy<Result<List<TimingChunk>>>(const Success([]));
  });

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    return ctx;
  }

  /// Runs [presses] end to end and returns the saved results.
  Future<List<RaceResult>> race(
      WidgetTester tester, List<_Press> presses) async {
    final finishers =
        presses.whereType<_Finish>().length;
    final roster = [for (var i = 1; i <= finishers; i++) _runner(i)];
    final times = [
      for (var i = 0; i < finishers; i++)
        Duration(milliseconds: (15 * 60 * 1000) + (i + 1) * 3210)
    ];
    final truth = [for (final t in times) fmt(t)];

    final ctx = await pumpContext(tester);
    final byBib = {for (final r in roster) r.runner.bibNumber!: r};
    final masterRace = MockMasterRace();
    when(masterRace.raceId).thenReturn(1);
    when(masterRace.getRaceRunnerByBib(any)).thenAnswer(
        (i) async => byBib[i.positionalArguments.first as String]);
    when(masterRace.saveResults(any)).thenAnswer((_) async {});

    final devices =
        DevicesManager(DeviceName.coach, DeviceType.browserDevice);
    final shared = await _runTimer(presses, times);
    devices.raceTimer!.data = shared;
    devices.bibRecorder!.data = await BibEncodeUtils.getEncodedBibData(
        [for (final r in roster) BibDatum.fromRaceRunner(r)]);

    final controller = LoadResultsController(
      masterRace: masterRace,
      devices: devices,
      scheduler: _NoopScheduler(),
    );
    await controller.processReceivedData(ctx);
    expect(controller.error?.userMessage, isNull,
        reason: 'pressed: ${_describe(presses)}\n'
            'shared: ${decodeAndDecompress(shared)}\n'
            'true:   ${truth.join(',')}');
    expect(controller.raceRunners, roster);

    final chunks = controller.timingChunks!;
    final merge = MergeConflictsController(
      masterRace: masterRace,
      timingChunks: chunks,
      raceRunners: roster,
      scheduler: _NoopScheduler(),
      recordedTimes: MergeConflictsController.recordedTimesOf(chunks),
    );
    merge.initState();
    await _resolve(merge, truth);
    final story = 'pressed: ${_describe(presses)}\n'
        'shared: ${chunks.map((c) => c.encode()).join(' | ')}\n'
        'true:   ${truth.join(',')}';
    expect(merge.hasConflicts, isFalse,
        reason: 'conflicts left unresolved\n$story');
    controller.hasTimingConflicts = controller.containsTimingConflicts();

    expect(await controller.saveCurrentResults(), isNull);
    final saved = verify(masterRace.saveResults(captureAny)).captured.single
        as List<RaceResult>;
    expect(saved.map((r) => r.runner!.runnerId),
        [for (var i = 1; i <= finishers; i++) i]);
    expect(saved.map((r) => r.place), [for (var i = 1; i <= finishers; i++) i]);
    expect(saved.map((r) => r.finishTime),
        [for (final t in times) TimeFormatter.loadDurationFromString(fmt(t))],
        reason: story);
    return saved;
  }

  const finish = _Finish();
  const missed = _Finish(logged: false);
  const stray = _Stray();
  const confirm = _Confirm();
  const missing = _MissingTime();
  const extra = _ExtraTime();
  const undo = _Undo();

  group('one kind of press at a time', () {
    testWidgets('no conflicts at all', (t) async {
      await race(t, [finish, finish, finish, finish]);
    });

    testWidgets('confirmations only', (t) async {
      await race(t, [
        finish, finish, confirm, finish, confirm, finish, finish, confirm, //
      ]);
    });

    testWidgets('two confirmations in a row', (t) async {
      await race(t, [finish, finish, confirm, confirm, finish, confirm]);
    });

    testWidgets('one missing time', (t) async {
      await race(t, [finish, missed, missing, finish, confirm]);
    });

    testWidgets('one extra time', (t) async {
      await race(t, [finish, finish, stray, extra, finish, confirm]);
    });
  });

  group('stacked conflicts', () {
    testWidgets('two missing times in a row', (t) async {
      await race(t, [finish, missed, missed, missing, missing, finish, confirm]);
    });

    testWidgets('three missing times in a row', (t) async {
      await race(t, [
        finish, missed, missed, missed, missing, missing, missing, finish, //
        confirm,
      ]);
    });

    testWidgets('two missing times, one after each missed runner', (t) async {
      await race(t, [
        finish, missed, missing, finish, missed, missing, finish, confirm, //
      ]);
    });

    testWidgets('two extra times in a row', (t) async {
      await race(t, [
        finish, finish, stray, stray, extra, extra, finish, confirm, //
      ]);
    });

    testWidgets('three extra times in a row', (t) async {
      await race(t, [
        finish, finish, stray, stray, stray, extra, extra, extra, finish, //
        confirm,
      ]);
    });

    testWidgets('two extra times, one after each stray tap', (t) async {
      await race(t, [
        finish, stray, extra, finish, stray, extra, finish, confirm, //
      ]);
    });

    testWidgets('missing times right after a confirmation', (t) async {
      await race(t, [
        finish, finish, confirm, missed, missed, missing, missing, finish, //
        confirm,
      ]);
    });

    testWidgets('missing and extra in the same batch', (t) async {
      await race(t, [
        finish, missed, missing, finish, stray, finish, confirm, //
      ]);
    });

    testWidgets('a missing time pressed by mistake is undone', (t) async {
      await race(t, [finish, finish, missing, undo, finish, confirm]);
    });

    testWidgets('an extra time pressed by mistake is undone', (t) async {
      await race(t, [finish, finish, stray, extra, undo, finish, confirm]);
    });

    testWidgets('one of two missing times is taken back', (t) async {
      await race(t, [
        finish, missed, missed, missing, missing, undo, finish, confirm, //
      ]);
    });

    testWidgets('a stray tap and then a missed runner keep both', (t) async {
      // These used to cancel out: the stray stayed in the results as a
      // finisher and the missed runner disappeared.
      await race(t, [
        finish, stray, extra, missed, missing, finish, confirm, //
      ]);
    });
  });

  group('conflicts in every position', () {
    testWidgets('a missing time before anyone finishes', (t) async {
      await race(t, [missed, missing, finish, finish, confirm]);
    });

    testWidgets('a missing time as the very last thing', (t) async {
      await race(t, [finish, finish, missed, missing]);
    });

    testWidgets('an extra time as the very last thing', (t) async {
      await race(t, [finish, finish, stray, extra]);
    });

    testWidgets('conflicts either side of a confirmation', (t) async {
      await race(t, [
        finish, missed, missing, finish, confirm, finish, stray, extra, //
        finish, confirm,
      ]);
    });

    testWidgets('every kind, one after another', (t) async {
      await race(t, [
        finish, confirm, missed, missing, finish, stray, extra, finish, //
        confirm, missed, missed, missing, missing, finish, finish, stray, //
        stray, extra, extra, finish, confirm,
      ]);
    });
  });

  group('the Timer did not notice', () {
    testWidgets('a missed runner after the last confirmation', (t) async {
      // The bibs show one more finisher than the Timer recorded.
      await race(t, [finish, finish, confirm, finish, missed, finish]);
    });

    testWidgets('a stray tap after the last confirmation', (t) async {
      await race(t, [finish, finish, confirm, finish, stray, finish]);
    });

    testWidgets('a missed runner on top of a marked extra time', (t) async {
      await race(t, [
        finish, finish, confirm, finish, stray, extra, missed, finish, //
      ]);
    });

    testWidgets('a stray tap on top of a marked missing time', (t) async {
      await race(t, [
        finish, finish, confirm, finish, missed, missing, stray, finish, //
      ]);
    });
  });

  group('random races', () {
    // Random button sequences, to catch combinations no one thought to write
    // down. Unmarked mistakes only happen after the last confirmation (a
    // confirmation means the count was agreed at that point), and at most one
    // per race: an unnoticed missed runner and an unnoticed stray tap in the
    // same race cancel out in the counts, which nothing can detect.
    for (var seed = 0; seed < 40; seed++) {
      testWidgets('seed $seed', (t) async {
        final random = Random(seed);
        final presses = <_Press>[];
        final finishers = 8 + random.nextInt(14);
        var logged = 0;
        while (logged < finishers) {
          switch (random.nextInt(10)) {
            case 0 when presses.isNotEmpty:
              presses.add(confirm);
            case 1:
              // Missed runners, marked straight away.
              final n = 1 + random.nextInt(3);
              for (var i = 0; i < n && logged < finishers; i++) {
                presses.add(missed);
                logged++;
              }
              for (var i = 0; i < n; i++) {
                presses.add(missing);
              }
            case 2:
              final n = 1 + random.nextInt(3);
              for (var i = 0; i < n; i++) {
                presses.add(stray);
              }
              for (var i = 0; i < n; i++) {
                presses.add(extra);
              }
            case 3 when presses.isNotEmpty:
              // A button pressed by mistake and taken back with undo.
              presses.add(missing);
              presses.add(undo);
            default:
              presses.add(finish);
              logged++;
          }
        }
        // One unnoticed mistake at the end, sometimes.
        switch (random.nextInt(3)) {
          case 0:
            presses.add(const _Finish(logged: false));
          case 1:
            presses.add(stray);
        }

        await race(t, presses);
      });
    }
  });
}
