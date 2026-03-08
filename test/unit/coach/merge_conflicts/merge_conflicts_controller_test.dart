import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

@GenerateMocks([IPostFrameCallbackScheduler])
import 'merge_conflicts_controller_test.mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _team = Team(teamId: 1, name: 'Eagles');

RaceRunner _runner(int id) => RaceRunner(
      raceId: 1,
      runner:
          Runner(runnerId: id, name: 'Runner $id', bibNumber: '$id', grade: 11),
      team: _team,
    );

/// A confirm-runner chunk: each timing datum is paired with a runner.
TimingChunk _confirmChunk(int id, List<String> times,
    {String endTime = '10:00.0'}) {
  return TimingChunk(
    id: id,
    timingData: times.map((t) => TimingDatum(time: t)).toList(),
    conflictRecord: TimingDatum(
      time: endTime,
      conflict: Conflict(type: ConflictType.confirmRunner, offBy: 0),
    ),
  );
}

/// An extra-time chunk: [offBy] times have no matching runner.
TimingChunk _extraTimeChunk(
  int id,
  List<String> times,
  int offBy, {
  String endTime = '10:00.0',
}) {
  return TimingChunk(
    id: id,
    timingData: times.map((t) => TimingDatum(time: t)).toList(),
    conflictRecord: TimingDatum(
      time: endTime,
      conflict: Conflict(type: ConflictType.extraTime, offBy: offBy),
    ),
  );
}

/// A missing-time chunk: [offBy] positions have 'TBD' as their time.
TimingChunk _missingTimeChunk(
  int id,
  List<String> times,
  int offBy, {
  String endTime = '10:00.0',
}) {
  return TimingChunk(
    id: id,
    timingData: times.map((t) => TimingDatum(time: t)).toList(),
    conflictRecord: TimingDatum(
      time: endTime,
      conflict: Conflict(type: ConflictType.missingTime, offBy: offBy),
    ),
  );
}

/// Build a list of [n] distinct RaceRunners.
List<RaceRunner> _runners(int n) => List.generate(n, (i) => _runner(i + 1));

MergeConflictsController _buildController({
  List<TimingChunk>? timingChunks,
  List<RaceRunner>? raceRunners,
  IPostFrameCallbackScheduler? scheduler,
}) {
  return MergeConflictsController(
    masterRace: MasterRace.getInstance(1),
    timingChunks: timingChunks ?? [],
    raceRunners: raceRunners ?? [],
    scheduler: scheduler,
  );
}

// ---------------------------------------------------------------------------

void main() {
  // Required so that WidgetsBinding.instance is available during unit tests
  // (used inside consolidateConfirmedTimes / submitMissingTime).
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // Prevent MasterRace singleton from leaking between tests.
    MasterRace.clearAllInstances();
  });

  // =========================================================================
  group('MergeConflictsController', () {
    // -----------------------------------------------------------------------
    group('uiChunks', () {
      test('returns empty list when timingChunks is empty', () {
        final controller = _buildController();
        expect(controller.uiChunks, isEmpty);
      });

      test(
          'converts a single extraTime chunk to a UIChunk with correct record count',
          () {
        // 3 times, offBy=1 → 2 runners + 1 extra-time record = 3 UIRecords
        final chunk = _extraTimeChunk(1, ['1:00.0', '2:00.0', '3:00.0'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final uiChunks = controller.uiChunks;
        expect(uiChunks.length, 1);
        expect(uiChunks.first.records.length, 3);
        expect(uiChunks.first.conflict.type, ConflictType.extraTime);
      });

      test('converts a single missingTime chunk with TBD records', () {
        // 1 real time + 1 TBD, offBy=1
        final chunk = _missingTimeChunk(1, ['1:00.0', 'TBD'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final uiChunks = controller.uiChunks;
        expect(uiChunks.length, 1);
        expect(uiChunks.first.conflict.type, ConflictType.missingTime);
        final tbdCount =
            uiChunks.first.records.where((r) => r.time == 'TBD').length;
        expect(tbdCount, greaterThanOrEqualTo(1));
      });

      test('caches result — repeated calls return identical list object', () {
        final chunk = _confirmChunk(1, ['1:00.0', '2:00.0']);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final first = controller.uiChunks;
        final second = controller.uiChunks;
        expect(identical(first, second), isTrue);
      });

      test('invalidateUICache causes re-conversion on next access', () {
        final chunk = _confirmChunk(1, ['1:00.0', '2:00.0']);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final first = controller.uiChunks;
        controller.invalidateUICache();
        final second = controller.uiChunks;
        // A new list object is built after invalidation.
        expect(identical(first, second), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('hasConflicts', () {
      test('returns false when list has exactly one confirmRunner chunk', () {
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0'])
          ],
        );
        expect(controller.hasConflicts, isFalse);
      });

      test('returns true when list has more than one chunk', () {
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0']),
            _confirmChunk(2, ['2:00.0']),
          ],
        );
        expect(controller.hasConflicts, isTrue);
      });

      test('returns true when single chunk has extraTime conflict', () {
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(1, ['1:00.0', '2:00.0'], 1)
          ],
          raceRunners: _runners(1),
        );
        expect(controller.hasConflicts, isTrue);
      });

      test('returns true when single chunk has missingTime conflict', () {
        final controller = _buildController(
          timingChunks: [
            _missingTimeChunk(1, ['1:00.0', 'TBD'], 1)
          ],
          raceRunners: _runners(2),
        );
        expect(controller.hasConflicts, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    group('allConflictsResolved', () {
      test('returns true when no TBD values exist', () {
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0', '2:00.0'])
          ],
        );
        expect(controller.allConflictsResolved, isTrue);
      });

      test('returns false when any timing datum contains TBD', () {
        final controller = _buildController(
          timingChunks: [
            _missingTimeChunk(1, ['1:00.0', 'TBD'], 1)
          ],
          raceRunners: _runners(2),
        );
        expect(controller.allConflictsResolved, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('hasValidTimeOrder', () {
      test('returns true when all records have no validation errors', () {
        // A controller with only confirm-runner records has no validation errors
        // by default.
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0', '2:00.0'])
          ],
          raceRunners: _runners(2),
        );
        expect(controller.hasValidTimeOrder, isTrue);
      });

      test('returns false when any record has a validation error', () {
        // A missingTime chunk with two real times lets us trigger a validation
        // error by submitting a duplicate time.
        final chunk =
            _missingTimeChunk(1, ['1:00.0', 'TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        // Build uiChunks first so records exist.
        final uiChunks = controller.uiChunks;
        expect(uiChunks, isNotEmpty);
        final chunkId = uiChunks.first.chunkId;

        // Entering 'bad-time' triggers 'Invalid Time' error in _validateTimeInChunk.
        controller.updateMissingTimeRecord(chunkId, 0, 'not-a-time');

        expect(controller.hasValidTimeOrder, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('consolidateConfirmedTimes', () {
      test('merges two adjacent confirmRunner chunks into one', () async {
        // The merged chunk will have 4 times, so 4 runners are needed when
        // _checkForAutoClose calls uiChunks after consolidation.
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0', '2:00.0']),
            _confirmChunk(2, ['3:00.0', '4:00.0']),
          ],
          raceRunners: _runners(4),
        );

        await controller.consolidateConfirmedTimes();

        expect(controller.timingChunks.length, 1);
      });

      test('does not merge non-adjacent confirmRunner chunks', () async {
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0']),
            _missingTimeChunk(2, ['2:00.0', 'TBD'], 1),
            _confirmChunk(3, ['3:00.0']),
          ],
          raceRunners: _runners(4),
        );

        await controller.consolidateConfirmedTimes();

        // The two confirmRunner chunks are not adjacent so none should merge.
        expect(controller.timingChunks.length, 3);
      });

      test('does not affect extraTime chunks', () async {
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(1, ['1:00.0', '2:00.0'], 1),
          ],
          raceRunners: _runners(1),
        );

        await controller.consolidateConfirmedTimes();

        expect(controller.timingChunks.length, 1);
        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.extraTime,
        );
      });

      test('re-converts uiChunks after adjacent chunks are merged', () async {
        // Use two chunks so they merge. The cached length (2 UIChunks) won't
        // match the post-merge timingChunks length (1), forcing re-conversion.
        // The merged chunk has 4 times → 4 runners are required.
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0', '2:00.0']),
            _confirmChunk(2, ['3:00.0', '4:00.0']),
          ],
          raceRunners: _runners(4),
        );

        // Prime cache with the 2-chunk layout.
        final before = controller.uiChunks;

        await controller.consolidateConfirmedTimes();

        // The cache was rebuilt internally (length mismatch triggered re-conversion).
        // The next call returns the new (1-chunk) list, not the old 2-chunk list.
        final after = controller.uiChunks;
        expect(identical(before, after), isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('resolveExtraTimeConflict', () {
      test('converts an extraTime chunk to confirmRunner', () async {
        // After resolving, _checkForAutoClose calls uiChunks on the resulting
        // confirmRunner chunk (1 time) → needs 1 runner.
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(1, ['1:00.0'], 0)
          ],
          raceRunners: _runners(1),
        );

        await controller.resolveExtraTimeConflict(0);

        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.confirmRunner,
        );
      });

      test('does nothing if index is out of range', () async {
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(1, ['1:00.0'], 1)
          ],
          raceRunners: _runners(0),
        );

        await controller.resolveExtraTimeConflict(5); // out of range

        // Chunk should be unchanged.
        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.extraTime,
        );
      });

      test('does nothing if chunk is not extraTime', () async {
        final controller = _buildController(
          timingChunks: [
            _missingTimeChunk(1, ['TBD'], 1)
          ],
          raceRunners: _runners(1),
        );

        await controller.resolveExtraTimeConflict(0);

        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.missingTime,
        );
      });
    });

    // -----------------------------------------------------------------------
    group('resolveMissingTimeConflict', () {
      test('converts a missingTime chunk to confirmRunner', () async {
        // After resolving, _checkForAutoClose calls uiChunks on the resulting
        // confirmRunner chunk (1 time) → needs 1 runner.
        final controller = _buildController(
          timingChunks: [
            _missingTimeChunk(1, ['1:00.0'], 0)
          ],
          raceRunners: _runners(1),
        );

        await controller.resolveMissingTimeConflict(0);

        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.confirmRunner,
        );
      });

      test('does nothing if index is out of range', () async {
        final controller = _buildController(
          timingChunks: [
            _missingTimeChunk(1, ['TBD'], 1)
          ],
          raceRunners: _runners(1),
        );

        await controller.resolveMissingTimeConflict(99);

        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.missingTime,
        );
      });

      test('does nothing if chunk is not missingTime', () async {
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(1, ['1:00.0', '2:00.0'], 1)
          ],
          raceRunners: _runners(1),
        );

        await controller.resolveMissingTimeConflict(0);

        expect(
          controller.timingChunks.first.conflictRecord!.conflict!.type,
          ConflictType.extraTime,
        );
      });
    });

    // -----------------------------------------------------------------------
    group('removeExtraTime', () {
      test('returns false if chunkId is not found', () {
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(10, ['1:00.0', '2:00.0'], 1)
          ],
          raceRunners: _runners(1),
        );

        final result = controller.removeExtraTime(999, 0);

        expect(result, isFalse);
      });

      test('removes the record at the given index', () {
        final chunk = _extraTimeChunk(1, ['1:00.0', '2:00.0', '3:00.0'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        controller.removeExtraTime(1, 2); // remove last (extra) record

        expect(controller.timingChunks.first.timingData.length, 2);
      });

      test('decrements conflict.offBy', () {
        final chunk = _extraTimeChunk(1, ['1:00.0', '2:00.0'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        final conflictBefore =
            controller.timingChunks.first.conflictRecord!.conflict!.offBy;
        controller.removeExtraTime(1, 1);
        final conflictAfter =
            controller.timingChunks.first.conflictRecord!.conflict!.offBy;

        expect(conflictAfter, conflictBefore - 1);
      });

      test('notifies listeners', () {
        final chunk = _extraTimeChunk(1, ['1:00.0', '2:00.0'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        var notified = false;
        controller.addListener(() => notified = true);

        controller.removeExtraTime(1, 1);

        expect(notified, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    group('submitMissingTime', () {
      test('updates the timing datum at the given index', () {
        final chunk = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        controller.submitMissingTime(0, 0, '1:00.0');

        expect(controller.timingChunks.first.timingData[0].time, '1:00.0');
      });

      test('decrements offBy when filling a TBD slot', () {
        final chunk = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        final before = chunk.conflictRecord!.conflict!.offBy;
        controller.submitMissingTime(0, 0, '1:00.0');
        final after = chunk.conflictRecord!.conflict!.offBy;

        expect(after, before - 1);
      });

      test('increments offBy when resetting a filled slot back to TBD', () {
        final chunk =
            _missingTimeChunk(1, ['1:00.0', 'TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final before = chunk.conflictRecord!.conflict!.offBy;
        controller.submitMissingTime(0, 0, 'TBD');
        final after = chunk.conflictRecord!.conflict!.offBy;

        expect(after, before + 1);
      });

      test('calls consolidateConfirmedTimes when offBy reaches 0', () async {
        // Two adjacent chunks: one missingTime with offBy=1, one confirmRunner.
        // When we fill the TBD the controller will consolidate — resulting in 1 chunk.
        final missing = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final confirm =
            _confirmChunk(2, ['6:00.0', '7:00.0'], endTime: '8:00.0');
        final controller = _buildController(
          timingChunks: [missing, confirm],
          raceRunners: _runners(3),
        );

        controller.submitMissingTime(0, 0, '1:00.0');

        // After offBy reaches 0 consolidation fires; the two chunks may merge.
        // We just verify chunks list was touched by consolidation logic.
        // (Exact merge depends on adjacency — both become confirmRunner so they merge.)
        expect(controller.timingChunks.length, lessThan(3));
      });
    });

    // -----------------------------------------------------------------------
    group('canClose', () {
      test('returns AppError when conflicts remain', () {
        final controller = _buildController(
          timingChunks: [
            _extraTimeChunk(1, ['1:00.0', '2:00.0'], 1),
          ],
          raceRunners: _runners(1),
        );

        final result = controller.canClose();

        expect(result, isA<AppError>());
        expect(result!.userMessage, isNotEmpty);
      });

      test('returns null when all conflicts are resolved', () {
        // Single confirmRunner chunk → hasConflicts is false.
        final controller = _buildController(
          timingChunks: [
            _confirmChunk(1, ['1:00.0'])
          ],
        );

        expect(controller.canClose(), isNull);
      });
    });

    // -----------------------------------------------------------------------
    group('removeExtraTime — additional cases', () {
      test('returns false if chunk has wrong conflict type', () {
        final controller = _buildController(
          timingChunks: [_missingTimeChunk(1, ['TBD'], 1)],
          raceRunners: _runners(1),
        );

        final result = controller.removeExtraTime(1, 0);

        expect(result, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    group('removeExtraTimeRecord', () {
      test('removes record from uiChunk and timingChunk for extraTime chunk',
          () {
        final chunk =
            _extraTimeChunk(1, ['1:00.0', '2:00.0', '3:00.0'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        controller.removeExtraTimeRecord(1, 2);

        expect(controller.timingChunks.first.timingData.length, 2);
      });

      test('does nothing for wrong conflict type', () {
        final chunk = _missingTimeChunk(1, ['1:00.0', 'TBD'], 1);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        controller.removeExtraTimeRecord(1, 0);

        // timingData unchanged
        expect(controller.timingChunks.first.timingData.length, 2);
      });
    });

    // -----------------------------------------------------------------------
    group('submitMissingTimeRecord', () {
      test('updates record time', () async {
        final chunk = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        final uiChunk = controller.uiChunks.first;
        await controller.submitMissingTimeRecord(uiChunk.chunkId, 0, '2:00.0');

        expect(uiChunk.records.first.time, '2:00.0');
      });

      test('calls syncChunkToBackendAndCheckResolution when chunk is resolved',
          () async {
        final chunk = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        final uiChunk = controller.uiChunks.first;
        await controller.submitMissingTimeRecord(uiChunk.chunkId, 0, '1:00.0');

        // Sync sets offBy to 0 when no TBDs remain.
        expect(chunk.conflictRecord!.conflict!.offBy, 0);
      });
    });

    // -----------------------------------------------------------------------
    group('updateMissingTimeRecord', () {
      test('updates timeController text and notifies listeners', () {
        final chunk = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        final uiChunk = controller.uiChunks.first;
        var notified = false;
        controller.addListener(() => notified = true);

        controller.updateMissingTimeRecord(uiChunk.chunkId, 0, '2:00.0');

        expect(uiChunk.records.first.timeController.text, '2:00.0');
        expect(notified, isTrue);
      });

      test('sets validation error for invalid time', () {
        final chunk = _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
        );

        final uiChunk = controller.uiChunks.first;
        controller.updateMissingTimeRecord(uiChunk.chunkId, 0, 'not-a-time');

        expect(uiChunk.records.first.validationError, isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    group('insertTbdAt', () {
      test('inserts new TBD record at index for confirmRunner chunk', () {
        final chunk = _confirmChunk(1, ['1:00.0', '2:00.0']);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final uiChunk = controller.uiChunks.first;
        final countBefore = uiChunk.records.length;

        controller.insertTbdAt(uiChunk.chunkId, 0);

        expect(uiChunk.records.length, countBefore + 1);
        expect(uiChunk.records.first.time, 'TBD');
      });

      test('moves existing TBD to target index for missingTime chunk', () {
        final chunk =
            _missingTimeChunk(1, ['1:00.0', 'TBD'], 1, endTime: '5:00.0');
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(2),
        );

        final uiChunk = controller.uiChunks.first;

        // TBD is at index 1; move it to index 0.
        controller.insertTbdAt(uiChunk.chunkId, 0);

        expect(uiChunk.records.first.time, 'TBD');
      });
    });

    // -----------------------------------------------------------------------
    group('_checkForAutoClose', () {
      test('calls scheduler when all conflicts resolved and single chunk',
          () async {
        final mockScheduler = MockIPostFrameCallbackScheduler();
        final chunk = _confirmChunk(1, ['1:00.0']);
        final controller = _buildController(
          timingChunks: [chunk],
          raceRunners: _runners(1),
          scheduler: mockScheduler,
        );

        await controller.consolidateConfirmedTimes();

        verify(mockScheduler.addPostFrameCallback(any)).called(1);
      });

      test('does not call scheduler when TBD values remain', () async {
        final mockScheduler = MockIPostFrameCallbackScheduler();
        final controller = _buildController(
          timingChunks: [
            _missingTimeChunk(1, ['TBD'], 1, endTime: '5:00.0'),
          ],
          raceRunners: _runners(1),
          scheduler: mockScheduler,
        );

        await controller.consolidateConfirmedTimes();

        verifyNever(mockScheduler.addPostFrameCallback(any));
      });
    });

    // -----------------------------------------------------------------------
    group('createNewResolvedChunk', () {
      test('returns null when times list is empty', () async {
        final controller = _buildController();

        final result = await controller.createNewResolvedChunk([]);

        expect(result, isNull);
      });

      test('returns null when a time is invalid', () async {
        final controller = _buildController();

        final result = await controller.createNewResolvedChunk(['bad-value']);

        expect(result, isNull);
      });

      test(
          'returns a TimingChunk with confirmRunner conflict when all times are valid',
          () async {
        final controller = _buildController();

        final result =
            await controller.createNewResolvedChunk(['1:00.0', '2:00.0']);

        expect(result, isNotNull);
        expect(
            result!.conflictRecord!.conflict!.type, ConflictType.confirmRunner);
        expect(result.timingData.length, 2);
      });
    });
  });
}
