import 'package:flutter/material.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/coach/resolve_bib_number_screen/widgets/bib_conflicts_overview.dart';
import 'package:xceleration/coach/merge_conflicts/screen/merge_conflicts_screen.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/utils/encode_utils.dart';
import '../../../../../merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

/// Controller that manages loading and processing of race results
class LoadResultsController with ChangeNotifier {
  final MasterRace masterRace;
  bool _resultsLoaded = false;
  bool _hasBibConflicts = false;
  bool _hasTimingConflicts = false;
  AppError? _error;
  List<RaceResult> results = [];
  List<TimingChunk>? timingChunks;

  /// One entry per finisher, in finish order: a [RaceRunner] once the bib is
  /// matched, or the bib number as a [String] while it still needs resolving
  /// (unknown or duplicate bib).
  List<dynamic>? raceRunners;
  final DevicesManager devices;

  // The last chunk's conflict as the Timer sent it, so the finisher count
  // can be reconciled again (e.g. after a bib is removed) from the original.
  TimingDatum? _lastConflictAsSent;
  bool _haveLastConflictAsSent = false;

  // Times the Timer recorded in each missing-time chunk; see
  // MergeConflictsController.recordedTimesOf.
  Map<int, Set<String>>? _recordedTimes;

  final Future<String> Function(MasterRace) _encodeBibData;
  final IPostFrameCallbackScheduler _scheduler;

  LoadResultsController({
    required this.masterRace,
    required this.devices,
    Future<String> Function(MasterRace)? encodeBibData,
    IPostFrameCallbackScheduler? scheduler,
  })  : _encodeBibData =
            encodeBibData ?? BibEncodeUtils.getEncodedRunnersBibData,
        _scheduler = scheduler ?? WidgetsBindingAdapter();

  void initialize() {
    _scheduler.addPostFrameCallback(() {
      loadResults();
    });
  }

  bool get resultsLoaded => _resultsLoaded;
  bool get hasBibConflicts => _hasBibConflicts;
  bool get hasTimingConflicts => _hasTimingConflicts;
  bool get hasError => _error != null;
  AppError? get error => _error;

  set resultsLoaded(bool value) {
    _resultsLoaded = value;
    notifyListeners();
  }

  set hasBibConflicts(bool value) {
    _hasBibConflicts = value;
    notifyListeners();
  }

  set hasTimingConflicts(bool value) {
    _hasTimingConflicts = value;
    notifyListeners();
  }

  /// Resets devices and clears state
  Future<void> resetDevices() async {
    devices.reset();
    // Re-encode and assign runner data after reset
    final encoded = await _encodeBibData(masterRace);
    devices.bibRecorder?.data = encoded;
    Logger.d('POST-RESET: Encoded runners data length: ${encoded.length}');
    _resultsLoaded = false;
    _hasBibConflicts = false;
    _hasTimingConflicts = false;
    _error = null;
    results = [];
    timingChunks = null;
    raceRunners = null;
    _recordedTimes = null;
    _haveLastConflictAsSent = false;
    notifyListeners();
  }

  /// Loads saved results from the database
  Future<void> loadResults() async {
    try {
      final List<RaceResult> savedResults = await masterRace.results;

      if (savedResults.isNotEmpty) {
        results = savedResults;
        _resultsLoaded = true;
      }
    } catch (e) {
      if (e.toString().contains('Race is not finished')) {
        Logger.d('Race is not finished yet - results not available');
      } else {
        Logger.e('Error loading results: $e');
      }
    }

    notifyListeners();
  }

  /// Saves race results to the database
  Future<void> saveRaceResults(List<RaceResult> results) async {
    try {
      await masterRace.saveResults(results);
    } catch (e) {
      Logger.d('Error in saveRaceResults: $e');
      rethrow;
    }
  }

  /// Saves the current race results when user explicitly requests it (e.g., clicks Next)
  ///
  /// Returns an error if the results could not be saved, so the flow can stay
  /// on this step instead of marking the race finished without results.
  Future<AppError?> saveCurrentResults() async {
    if (hasBibConflicts || hasTimingConflicts) {
      return const AppError(
          userMessage: 'Resolve all conflicts before saving the results.');
    }
    if (timingChunks == null || raceRunners == null) {
      // Nothing newly loaded: results already saved earlier are kept.
      return null;
    }
    final error = await _mergeBibDataWithTimingChunksAndSaveResults();
    notifyListeners();
    return error;
  }

  /// Processes data received from devices
  Future<void> processReceivedData(BuildContext context) async {
    String? bibRecordsData = devices.bibRecorder?.data;
    String? finishTimesData = devices.raceTimer?.data;

    Logger.d(
        'Bib records data: ${bibRecordsData != null ? "Available" : "Null"}');
    Logger.d(
        'Finish times data: ${finishTimesData != null ? "Available" : "Null"}');

    if (bibRecordsData != null && finishTimesData != null) {
      _error = null;
      final bibResult =
          await BibDecodeUtils.decodeEncodedRunners(bibRecordsData);
      final List<BibDatum> bibData;
      switch (bibResult) {
        case Success(:final value):
          bibData = value;
        case Failure(:final error):
          Logger.e(
              '[LoadResultsController.processReceivedData] ${error.originalException}');
          _loadFailed(error);
          return;
      }

      Logger.d('Loaded bib data: ${bibData.length}');

      raceRunners = await Future.wait(
        bibData.map((bibDatum) async {
          Logger.d('LoadResultsController: Processing bib: ${bibDatum.bib}');
          final found = await masterRace.getRaceRunnerByBib(bibDatum.bib);
          if (found != null) {
            Logger.d(
                'LoadResultsController: Found race runner for bib ${bibDatum.bib}: ${found.runner.name}');
            return found;
          } else {
            Logger.d(
                'LoadResultsController: No race runner found for bib ${bibDatum.bib}, returning bib number as conflict');
            // Keep the bib as text: bibs are not always numeric, and parsing
            // to int turned "A12" into 0.
            return bibDatum.bib;
          }
        }),
      );

      // Check for duplicate bibs and convert duplicates to integers
      if (raceRunners != null && raceRunners!.isNotEmpty) {
        final Set<String> seenBibs = <String>{};
        for (int i = 0; i < raceRunners!.length; i++) {
          final entry = raceRunners![i];
          if (entry is RaceRunner) {
            final bibNumber = entry.runner.bibNumber!;
            if (seenBibs.contains(bibNumber)) {
              // A duplicate bib needs resolving: keep it as a conflict entry.
              raceRunners![i] = bibNumber;
              Logger.d(
                  'LoadResultsController: Marked duplicate bib $bibNumber as a conflict');
            } else {
              seenBibs.add(bibNumber);
            }
          }
        }
      }

      Logger.d(
          'LoadResultsController: Processed raceRunners: ${raceRunners?.length ?? 0} entries');

      if (raceRunners!.isEmpty) {
        // Without bibs nothing would be saved, yet the step could still be
        // finished: stop here instead.
        Logger.e('LoadResultsController: No race runners loaded');
        _loadFailed(const AppError(
            userMessage: 'No bib numbers were received from the Bib '
                'Recorder. Ask it to share again.'));
        return;
      } else {
        Logger.d(
            'LoadResultsController: Race runners loaded successfully: ${raceRunners!.length} entries');
      }

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      // Strict: a time that cannot be read must stop the load, since
      // dropping it would shift every later time onto the wrong runner.
      final List<TimingDatum> timingData;
      try {
        timingData = await TimingDecodeUtils.decodeEncodedTimingData(
            finishTimesData,
            strict: true);
      } on FormatException catch (e) {
        Logger.e('[LoadResultsController.processReceivedData] $e');
        _loadFailed(AppError(
          userMessage:
              'Some finish times could not be read. Ask the Timer to share again.',
          originalException: e,
        ));
        return;
      }

      Logger.d('Loaded timing data: ${timingData.length}');
      if (timingData.isEmpty) {
        _loadFailed(const AppError(
            userMessage:
                'No finish times were received from the Timer. Ask the Timer to share again.'));
        return;
      }

      // Immediately convert to timing chunks for internal use
      timingChunks = timingChunksFromTimingData(timingData);

      Logger.d('Converted to timing chunks: ${timingChunks?.length ?? 0}');

      // Check if context is still mounted after second async operation
      if (!context.mounted) return;

      _recordedTimes = null;
      final foldError = _foldExtraTimesIntoConfirmedChunks();
      _lastConflictAsSent = _copy(timingChunks!.last.conflictRecord);
      _haveLastConflictAsSent = true;
      final error = foldError ?? _reconcileFinisherCounts();
      if (error != null) {
        _loadFailed(error);
        return;
      }

      _resultsLoaded = true;
      await _checkForConflicts();
    } else {
      Logger.e(
          'Missing data source: bibRecordsData or finishTimesData is null');
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(
        context,
        message: 'No data received from assistant devices.',
      );
    }
  }

  /// Records why loading failed and drops the half-loaded data, so nothing
  /// from a failed load can be resolved or saved. Results saved earlier are
  /// kept.
  void _loadFailed(AppError error) {
    _error = error;
    timingChunks = null;
    raceRunners = null;
    _recordedTimes = null;
    _hasBibConflicts = false;
    _hasTimingConflicts = false;
    notifyListeners();
  }

  /// Older Timer versions allowed "extra time" straight after a confirmation,
  /// leaving an extra-time chunk with fewer times than it says are extra; the
  /// extras are among the confirmed times before it. Merges those confirmed
  /// chunks into it so the coach can pick which times to remove.
  AppError? _foldExtraTimesIntoConfirmedChunks() {
    final chunks = timingChunks!;
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final conflict = chunk.conflictRecord?.conflict;
      if (conflict?.type != ConflictType.extraTime) continue;
      while (chunk.timingData.length < conflict!.offBy &&
          i > 0 &&
          chunks[i - 1].conflictRecord?.conflict?.type ==
              ConflictType.confirmRunner) {
        chunk.timingData.insertAll(0, chunks[i - 1].timingData);
        chunks.removeAt(i - 1);
        i--;
      }
      if (chunk.timingData.length < conflict.offBy) {
        return const AppError(
            userMessage: 'The Timer marked more extra times than it recorded. '
                'Check the Timer and share again.');
      }
    }
    return null;
  }

  /// Calculates total timing records across all chunks
  int _calculateTotalTimingRecords() {
    if (timingChunks == null) return 0;
    return timingChunks!.fold(0, (sum, chunk) => sum + chunk.recordCount);
  }

  /// Makes the Timer's finisher count match the number of bibs by adjusting
  /// the last timing chunk's conflict, so the difference shows up as a timing
  /// conflict for the coach to resolve. Nothing is removed automatically:
  ///
  /// - More bibs than finishers: the Timer missed some finishers, so the last
  ///   chunk gets that many missing times (TBD slots the coach fills in and
  ///   can move to the right place).
  /// - More finishers than bibs: the last chunk gets that many extra times
  ///   for the coach to remove.
  ///
  /// Returns an error if the difference can't be shown that way.
  AppError? _reconcileFinisherCounts() {
    final chunks = timingChunks;
    final runners = raceRunners;
    if (chunks == null || runners == null || chunks.isEmpty) return null;

    // Start from the conflict as the Timer sent it, so running this again
    // gives the same answer as running it once with the current bibs.
    if (_haveLastConflictAsSent) {
      chunks.last.conflictRecord = _copy(_lastConflictAsSent);
    }

    final diff = runners.length - _calculateTotalTimingRecords();
    if (diff == 0) return null;
    Logger.d('LoadResultsController: bibs and finishers differ by $diff');

    final last = chunks.last;
    final current = last.conflictRecord?.conflict;
    // The Timer marked the opposite problem in this chunk (an extra time
    // while the bibs say finishers are missing, or the reverse). Both are
    // real: netting them out made the chunk look confirmed, and the stray
    // time was saved in place of the missed runner. Keep the Timer's mark;
    // what is left over becomes a new conflict once the coach has resolved
    // it (see MergeConflictsController).
    if ((current?.type == ConflictType.extraTime && diff > 0) ||
        (current?.type == ConflictType.missingTime && diff < 0)) {
      return null;
    }
    final net = switch (current?.type) {
          ConflictType.missingTime => current!.offBy,
          ConflictType.extraTime => -current!.offBy,
          _ => 0,
        } +
        diff;

    if (net < 0 && -net > last.timingData.length) {
      // More extra times than the last chunk holds: the coach cannot resolve
      // this from the last chunk alone, so stop instead of guessing.
      return AppError(
        userMessage: 'The Timer recorded ${-diff} more finishers than the Bib '
            'Recorder. Check both devices and share again.',
      );
    }

    // Missing finishers can finish after the Timer's last checkpoint, so
    // their conflict gets no end time to validate against.
    final time = net > 0
        ? 'MISSING_TIMES'
        : last.conflictRecord?.time ??
            (last.timingData.isNotEmpty ? last.timingData.last.time : '0.0');
    last.conflictRecord = TimingDatum(
      time: time,
      conflict: net > 0
          ? Conflict(type: ConflictType.missingTime, offBy: net)
          : net < 0
              ? Conflict(type: ConflictType.extraTime, offBy: -net)
              : Conflict(type: ConflictType.confirmRunner, offBy: 1),
    );
    return null;
  }

  static TimingDatum? _copy(TimingDatum? datum) {
    final conflict = datum?.conflict;
    if (datum == null || conflict == null) return null;
    return TimingDatum(
        time: datum.time,
        conflict: Conflict(type: conflict.type, offBy: conflict.offBy));
  }

  Future<void> _checkForConflicts() async {
    _hasBibConflicts = containsBibConflicts();
    _hasTimingConflicts = containsTimingConflicts();
    Logger.d(
        'LoadResultsController: Conflict check - Bib conflicts: $hasBibConflicts, Timing conflicts: $hasTimingConflicts');
    Logger.d(
        'LoadResultsController: Race runners count: ${raceRunners?.length}, Timing chunks count: ${timingChunks?.length}');
    notifyListeners();
  }

  /// Merges runner records with timing chunks
  Future<AppError?> _mergeBibDataWithTimingChunksAndSaveResults() async {
    if (timingChunks == null || raceRunners == null) {
      Logger.e('LoadResultsController: Timing chunks or race runners is null');
      return const AppError(userMessage: 'No results are loaded to save.');
    }

    // Flatten timing chunks into individual timing records, excluding conflicts
    List<TimingDatum> timingRecords = [];
    for (var chunk in timingChunks!) {
      timingRecords.addAll(chunk.timingData);
    }

    if (timingRecords.length != raceRunners!.length) {
      Logger.e(
          'LoadResultsController: Timing records and race runners count mismatch: ${timingRecords.length} vs ${raceRunners!.length}');
      return _saveFailed(AppError(
        userMessage: 'There are ${timingRecords.length} finish times but '
            '${raceRunners!.length} runners. Resolve the timing conflicts first.',
      ));
    }
    if (raceRunners!.any((r) => r is! RaceRunner)) {
      return _saveFailed(const AppError(
          userMessage: 'Resolve all bib numbers before saving the results.'));
    }
    // Each runner finishes once. Bib resolution prevents duplicates; this is
    // the last check before anything is written.
    final seen = <int>{};
    for (final raceRunner in raceRunners!.cast<RaceRunner>()) {
      final id = raceRunner.runner.runnerId;
      if (id == null || !seen.add(id)) {
        return _saveFailed(AppError(
          userMessage: '${raceRunner.runner.name ?? 'A runner'} (bib '
              '${raceRunner.runner.bibNumber}) appears more than once. '
              'Check the bib numbers and load the results again.',
        ));
      }
    }

    Logger.d(
        'LoadResultsController: Starting to save ${timingRecords.length} results');

    final merged = <RaceResult>[];
    for (var i = 0; i < timingRecords.length; i++) {
      final raceRunner = raceRunners![i];
      final timingDatum = timingRecords[i];

      // Never save a time that cannot be read: defaulting to zero made the
      // runner the race winner.
      final finishDuration =
          TimeFormatter.loadDurationFromString(timingDatum.time);
      if (finishDuration == null) {
        return _saveFailed(AppError(
          userMessage: 'The time for place ${i + 1} ("${timingDatum.time}") '
              'is not valid. Fix it in the timing conflicts first.',
        ));
      }

      merged.add(RaceResult(
        raceId: masterRace.raceId,
        runner: raceRunner.runner,
        team: raceRunner.team,
        place: i + 1, // 1-based place
        finishTime: finishDuration,
      ));
    }

    // One call so a reload after a correction replaces the earlier results
    // as a whole instead of each runner being rejected as a duplicate.
    try {
      await masterRace.saveResults(merged);
      _error = null;
      results = merged;
      return null;
    } catch (e) {
      Logger.e('[LoadResultsController._mergeBibDataWithTimingChunks] $e');
      return _saveFailed(AppError(
        userMessage: 'Could not save the results. Please try again.',
        originalException: e,
      ));
    }
  }

  AppError _saveFailed(AppError error) {
    _error = error;
    return error;
  }

  /// Shows sheet for resolving bib conflicts
  Future<void> showBibConflictsSheet(BuildContext context) async {
    if (raceRunners == null) {
      Logger.d('Race runners is null, showing error dialog');
      DialogUtils.showErrorDialog(
        context,
        message:
            'Runner data is missing. Connect to your assistant device and load results first.',
      );
      return;
    }

    // Check for bib conflicts
    final hadBibConflicts = raceRunners!.any((runner) => runner is String);

    if (!hadBibConflicts) {
      Logger.d('No bib conflicts found, showing info dialog');
      DialogUtils.showErrorDialog(
        context,
        message: 'No bib number conflicts found to resolve.',
      );
      return;
    }

    List<RaceRunner?>? updatedRaceRunners;
    try {
      // Check if context is still mounted
      if (!context.mounted) {
        Logger.d('Context is not mounted, cannot show sheet');
        return;
      }

      // Try to create the BibConflictsOverview widget first
      final bibConflictsWidget = BibConflictsOverview(
        masterRace: masterRace,
        raceRunners: raceRunners!, // Pass the full list including conflicts
        onResolved: (updatedRaceRunners) {
          Navigator.pop(context, updatedRaceRunners);
        },
      );

      updatedRaceRunners = await sheet(
        context: context,
        title: 'Resolve Bib Numbers',
        body: bibConflictsWidget,
        useRootNavigator: true,
      );
    } catch (e, stackTrace) {
      Logger.e('Error showing bib conflicts sheet: $e');
      Logger.e('Stack trace: $stackTrace');
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(
        context,
        message: 'Failed to open bib conflict resolution sheet: $e',
      );
      return;
    }

    // Update runner records only if a result was returned (conflicts were actually resolved)
    if (updatedRaceRunners != null) {
      await applyResolvedRunners(updatedRaceRunners);
    }

    // If there are still timing conflicts, open the timing conflicts sheet
    if (hasTimingConflicts &&
        !hasBibConflicts &&
        timingChunks != null &&
        context.mounted) {
      if (!context.mounted) return;
      await showTimingConflictsSheet(context);
    }
  }

  /// Takes the runners from the bib sheet once every bib is resolved.
  @visibleForTesting
  Future<void> applyResolvedRunners(List<RaceRunner?> updated) async {
    final removed = raceRunners!.length != updated.length;
    raceRunners = updated;
    if (removed) {
      // A bib entered by mistake was removed: the finisher counts must be
      // matched against the Timer's again.
      _recordedTimes = null;
      final error = _reconcileFinisherCounts();
      if (error != null) {
        _error = error;
        notifyListeners();
      }
    }
    await _checkForConflicts();
  }

  /// Shows sheet for resolving timing conflicts
  Future<void> showTimingConflictsSheet(BuildContext context) async {
    Logger.d('showTimingConflictsSheet called');
    Logger.d('Timing chunks: $timingChunks');
    Logger.d('Race runners: $raceRunners');
    Logger.d('Context: $context');
    Logger.d('Context mounted: ${context.mounted}');

    if (timingChunks == null) {
      Logger.d('Timing chunks is null, showing error dialog');
      DialogUtils.showErrorDialog(
        context,
        message:
            'Timing data is missing. Connect to your assistant device and load results first.',
      );
      return;
    }
    if (raceRunners == null) {
      Logger.d('Race runners is null, showing error dialog');
      DialogUtils.showErrorDialog(
        context,
        message:
            'Runner data is missing. Connect to your assistant device and load results first.',
      );
      return;
    }

    // Only include chunks that actually have a conflict to avoid UI build errors
    final List<TimingChunk> conflictChunks =
        timingChunks!.where((c) => c.hasConflict).toList();
    Logger.d(
        'Found ${conflictChunks.length} conflict chunks out of ${timingChunks!.length} total chunks');
    Logger.d(
        'Conflict chunks details: ${conflictChunks.map((c) => 'hasConflict=${c.hasConflict}, recordCount=${c.recordCount}').toList()}');

    if (conflictChunks.isEmpty) {
      Logger.d('No conflict chunks found, showing info dialog');
      DialogUtils.showErrorDialog(
        context,
        message: 'No timing conflicts found to resolve.',
      );
      return;
    }

    final runners = raceRunners!.whereType<RaceRunner>().toList();
    try {
      // Pass the full list in finish order. The controller edits it in place;
      // resolving a filtered copy and appending it back reordered the chunks,
      // so later times landed on the wrong runners.
      await sheet(
        context: context,
        title: 'Resolve Timing Conflicts',
        body: ChangeNotifierProvider(
          create: (_) => MergeConflictsController(
            masterRace: masterRace,
            timingChunks: timingChunks!,
            raceRunners: runners,
            recordedTimes: _recordedTimes ??=
                MergeConflictsController.recordedTimesOf(timingChunks!),
          ),
          child: MergeConflictsScreen(
            masterRace: masterRace,
            timingChunks: timingChunks!,
            raceRunners: runners,
          ),
        ),
        useBottomPadding: false,
        useRootNavigator: true,
      );
      Logger.d('Sheet function completed successfully');
      // Don't auto-save results - wait for user to click save/next
    } catch (e, stackTrace) {
      Logger.d('Error showing timing conflicts sheet: $e');
      Logger.d('Stack trace: $stackTrace');
      if (!context.mounted) return;
      DialogUtils.showErrorDialog(
        context,
        message: 'Failed to open conflict resolution sheet: $e',
      );
      return;
    }
    await _checkForConflicts();
  }

  /// Checks if there are any bib conflicts in the provided records
  bool containsBibConflicts() {
    if (raceRunners == null) return false;
    return raceRunners!.any((runner) => runner is String);
  }

  /// Checks if there are any timing conflicts in the timing chunks
  bool containsTimingConflicts() {
    if (timingChunks == null) return false;

    return timingChunks!.any((chunk) =>
        chunk.hasConflict &&
        chunk.conflictRecord!.conflict!.type != ConflictType.confirmRunner);
  }
}
