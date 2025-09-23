import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
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
  List<RaceResult> results = [];
  List<TimingChunk>? timingChunks;
  List<dynamic>? raceRunners;
  late final DevicesManager devices;

  LoadResultsController({
    required this.masterRace,
  }) {
    devices = DeviceConnectionService.createDevices(
      DeviceName.coach,
      DeviceType.browserDevice,
    );

    // Load any existing results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadResults();
    });
  }

  bool get resultsLoaded => _resultsLoaded;
  bool get hasBibConflicts => _hasBibConflicts;
  bool get hasTimingConflicts => _hasTimingConflicts;

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
    final encoded = await BibEncodeUtils.getEncodedRunnersBibData(masterRace);
    devices.bibRecorder?.data = encoded;
    Logger.d('POST-RESET: Encoded runners data length: ${encoded.length}');
    resultsLoaded = false;
    hasBibConflicts = false;
    hasTimingConflicts = false;
    results = [];
    timingChunks = null;
    raceRunners = null;
    notifyListeners();
  }

  /// Loads saved results from the database
  Future<void> loadResults() async {
    try {
      final List<RaceResult> savedResults = await masterRace.results;

      if (savedResults.isNotEmpty) {
        results = savedResults;
        resultsLoaded = true;
      }
    } catch (e) {
      Logger.e('Error loading results: $e');
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
  Future<void> saveCurrentResults() async {
    Logger.d('User requested to save current results');
    if (!hasBibConflicts &&
        !hasTimingConflicts &&
        timingChunks != null &&
        raceRunners != null) {
      await _mergeBibDataWithTimingChunksAndSaveResults();
      notifyListeners();
      Logger.d('Results saved successfully');
    } else {
      Logger.d(
          'Cannot save results - conflicts still exist or data incomplete');
      Logger.d(
          'Bib conflicts: $hasBibConflicts, Timing conflicts: $hasTimingConflicts');
    }
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
      final List<BibDatum>? bibData =
          await BibDecodeUtils.decodeEncodedRunners(bibRecordsData, context);

      Logger.d('Loaded bib data: ${bibData?.length ?? 'null'}');

      raceRunners = bibData == null
          ? []
          : await Future.wait(
              bibData.map((bibDatum) async {
                Logger.d(
                    'LoadResultsController: Processing bib: ${bibDatum.bib}');
                final found = await masterRace.getRaceRunnerByBib(bibDatum.bib);
                if (found != null) {
                  Logger.d(
                      'LoadResultsController: Found race runner for bib ${bibDatum.bib}: ${found.runner.name}');
                  return found;
                } else {
                  Logger.d(
                      'LoadResultsController: No race runner found for bib ${bibDatum.bib}, returning bib number as conflict');
                  return int.tryParse(bibDatum.bib) ?? 0;
                }
              }),
            );

      Logger.d(
          'LoadResultsController: Processed raceRunners: ${raceRunners?.length ?? 0} entries');

      if (raceRunners!.isEmpty) {
        Logger.e('LoadResultsController: No race runners loaded');
        raceRunners = null;
      } else {
        Logger.d(
            'LoadResultsController: Race runners loaded successfully: ${raceRunners!.length} entries');
      }

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      // Decode timing data using existing method
      final timingData =
          await TimingDecodeUtils.decodeEncodedTimingData(finishTimesData);

      Logger.d('Loaded timing data: ${timingData.length}');

      // Immediately convert to timing chunks for internal use
      timingChunks = timingChunksFromTimingData(timingData);

      Logger.d('Converted to timing chunks: ${timingChunks?.length ?? 0}');

      // Check if context is still mounted after second async operation
      if (!context.mounted) return;

      _resultsLoaded = true;
      notifyListeners();

      await _ensureBibNumberAndRunnerRecordLengthsAreEqual();

      await _checkForConflicts();
    } else {
      Logger.e(
          'Missing data source: bibRecordsData or finishTimesData is null');
      DialogUtils.showErrorDialog(
        context,
        message: 'No data received from assistant devices.',
      );
    }
  }

  /// Calculates total timing records across all chunks
  int _calculateTotalTimingRecords() {
    if (timingChunks == null) return 0;
    return timingChunks!.fold(0, (sum, chunk) => sum + chunk.recordCount);
  }

  Future<void> _ensureBibNumberAndRunnerRecordLengthsAreEqual() async {
    if (raceRunners != null && timingChunks != null) {
      int totalTimingRecords = _calculateTotalTimingRecords();

      if (raceRunners!.length == totalTimingRecords) {
        // They are equal
        return;
      }

      Logger.d('Bib number and timing record lengths are not equal');
      int diff = raceRunners!.length - totalTimingRecords;
      Logger.d(
          'Difference: $diff (raceRunners: ${raceRunners!.length}, timingRecords: $totalTimingRecords)');

      if (diff > 0) {
        // More race runners than timing records - remove excess race runners
        // But preserve conflict entries (integers) for resolution
        Logger.d(
            'Removing $diff records from race runners (preserving conflicts)');
        Logger.d('Before removal: raceRunners length = ${raceRunners!.length}');

        // Count how many valid RaceRunner entries we have vs conflicts (integers)
        int validRunnerCount = raceRunners!.whereType<RaceRunner>().length;
        int conflictCount =
            raceRunners!.whereType<int>().length; // Keep as is for int type
        Logger.d('Valid runners: $validRunnerCount, Conflicts: $conflictCount');

        // Only remove from the valid runners, keep conflicts for resolution
        if (validRunnerCount >= diff) {
          // Remove excess valid runners only
          int removeCount = diff;
          raceRunners!.removeWhere((runner) {
            if (removeCount > 0 && runner is RaceRunner) {
              removeCount--;
              return true;
            }
            return false;
          });
          Logger.d(
              'Removed $diff excess valid runners, kept $conflictCount conflicts');
        } else {
          // Not enough valid runners to remove, this shouldn't happen in normal flow
          Logger.d(
              'Warning: Not enough valid runners to remove: need $diff, have $validRunnerCount');
        }

        Logger.d('After removal: raceRunners length = ${raceRunners!.length}');
      } else if (diff < 0) {
        // More timing records than race runners - add missing time conflict
        Logger.d('Adding ${diff.abs()} missing time records');

        // Check if the last chunk already has a missing time conflict
        if (timingChunks!.isNotEmpty &&
            timingChunks!.last.hasConflict &&
            timingChunks!.last.conflictRecord!.conflict!.type ==
                ConflictType.missingTime) {
          // Increase the offBy of the existing conflict
          timingChunks!.last.conflictRecord!.conflict!.offBy += diff.abs();
          Logger.d(
              'Increased existing missing time conflict offBy to: ${timingChunks!.last.conflictRecord!.conflict!.offBy}');
        } else {
          // Create a new conflict chunk
          timingChunks!.add(TimingChunk(
            timingData: [],
            conflictRecord: TimingDatum(
              time: 'MISSING_TIMES',
              conflict:
                  Conflict(type: ConflictType.missingTime, offBy: diff.abs()),
            ),
          ));
          Logger.d(
              'Added new missing time conflict chunk with offBy: ${diff.abs()}');
        }
      }
    }
  }

  Future<void> _checkForConflicts() async {
    hasBibConflicts = containsBibConflicts();
    hasTimingConflicts = containsTimingConflicts();
    Logger.d(
        'LoadResultsController: Conflict check - Bib conflicts: $hasBibConflicts, Timing conflicts: $hasTimingConflicts');
    Logger.d(
        'LoadResultsController: Race runners count: ${raceRunners?.length}, Timing chunks count: ${timingChunks?.length}');
    notifyListeners();
  }

  /// Merges runner records with timing chunks
  Future<List<RaceResult>> _mergeBibDataWithTimingChunksAndSaveResults() async {
    if (timingChunks == null || raceRunners == null) {
      Logger.e('LoadResultsController: Timing chunks or race runners is null');
      return [];
    }

    // Flatten timing chunks into individual timing records, excluding conflicts
    List<TimingDatum> timingRecords = [];
    for (var chunk in timingChunks!) {
      timingRecords.addAll(chunk.timingData);
    }

    if (timingRecords.length != raceRunners!.length) {
      Logger.e(
          'LoadResultsController: Timing records and race runners count mismatch: ${timingRecords.length} vs ${raceRunners!.length}');
      return [];
    }

    Logger.d(
        'LoadResultsController: Starting to save ${timingRecords.length} results');

    for (var i = 0; i < timingRecords.length; i++) {
      final raceRunner = raceRunners![i];
      final timingDatum = timingRecords[i];

      Logger.d(
          'LoadResultsController: Processing result ${i + 1}/${timingRecords.length}');

      // Convert elapsed time string to Duration
      Duration finishDuration;
      finishDuration = TimeFormatter.loadDurationFromString(timingDatum.time) ??
          Duration.zero;

      // Skip if runner is null; it will be handled by resolver later
      if (raceRunner == null) {
        continue;
      }

      final runner = raceRunner.runner;
      final team = raceRunner.team;

      Logger.d(
          'LoadResultsController: About to save result for runner: ${runner.name}, place: ${i + 1}, team: ${team.name}');
      print(
          '🔥 LoadResultsController: Team details - name: ${team.name}, teamId: ${team.teamId}, abbreviation: ${team.abbreviation}, isValid: ${team.isValid}');
      print(
          '🔥 LoadResultsController: Runner details - name: ${runner.name}, runnerId: ${runner.runnerId}, bib: ${runner.bibNumber}, isValid: ${runner.isValid}');

      try {
        final raceResult = RaceResult(
          raceId: masterRace.raceId, // Add missing raceId
          runner: runner,
          team: team,
          place: i + 1, // 1-based place
          finishTime: finishDuration,
        );
        print(
            '🔥 LoadResultsController: Created RaceResult - isValid: ${raceResult.isValid}, raceId: ${raceResult.raceId}, resultId: ${raceResult.resultId}');

        await masterRace.addResult(raceResult);
        print(
            '🔥 LoadResultsController: Successfully saved result for runner: ${runner.name}');
      } catch (e) {
        print(
            '🔥 LoadResultsController: Failed to save result for runner: ${runner.name}, error: $e');
      }
    }

    Logger.d(
        'LoadResultsController: Finished saving results, now fetching them back');
    results = await masterRace.results;
    Logger.d(
        'LoadResultsController: Data merged, created ${results.length} result records for raceId: ${masterRace.raceId}');
    Logger.d(
        'LoadResultsController: MasterRace instance: ${masterRace.hashCode}');

    return results;
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
    final hasBibConflicts = raceRunners!.any((runner) => runner is int);

    if (!hasBibConflicts) {
      Logger.d('No bib conflicts found, showing info dialog');
      DialogUtils.showErrorDialog(
        context,
        message: 'No bib number conflicts found to resolve.',
      );
      return;
    }

    Logger.d('About to call sheet function for bib conflicts');
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
      DialogUtils.showErrorDialog(
        context,
        message: 'Failed to open bib conflict resolution sheet: $e',
      );
      return;
    }

    // Update runner records if a result was returned
    if (updatedRaceRunners != null) {
      raceRunners = updatedRaceRunners;
      await _checkForConflicts();

      // If there are still timing conflicts, open the timing conflicts sheet
      if (hasTimingConflicts &&
          !hasBibConflicts &&
          timingChunks != null &&
          context.mounted) {
        await showTimingConflictsSheet(context);
      }
    }
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

    Logger.d('About to call sheet function');
    List<TimingChunk>? updatedTimingChunks;
    try {
      updatedTimingChunks = await sheet(
        context: context,
        title: 'Resolve Timing Conflicts',
        body: ChangeNotifierProvider(
          create: (_) => MergeConflictsController(
            masterRace: masterRace,
            timingChunks: conflictChunks,
            raceRunners: raceRunners!.whereType<RaceRunner>().toList(),
          ),
          child: MergeConflictsScreen(
            masterRace: masterRace,
            timingChunks: conflictChunks,
            raceRunners: raceRunners!.whereType<RaceRunner>().toList(),
          ),
        ),
        useBottomPadding: false,
        useRootNavigator: true,
      );
      Logger.d('Sheet function completed successfully');
    } catch (e, stackTrace) {
      Logger.d('Error showing timing conflicts sheet: $e');
      Logger.d('Stack trace: $stackTrace');
      DialogUtils.showErrorDialog(
        context,
        message: 'Failed to open conflict resolution sheet: $e',
      );
      return;
    }

    // Update timing chunks if a result was returned
    if (updatedTimingChunks != null) {
      // Find and replace the conflict chunks with the updated ones
      for (var i = 0; i < timingChunks!.length; i++) {
        if (timingChunks![i].hasConflict) {
          // Find the corresponding updated chunk
          final updatedChunk = updatedTimingChunks.firstWhere(
            (chunk) => chunk == timingChunks![i],
            orElse: () => timingChunks![i],
          );
          timingChunks![i] = updatedChunk;
        }
      }

      await _checkForConflicts();
    }
  }

  /// Checks if there are any bib conflicts in the provided records
  bool containsBibConflicts() {
    if (raceRunners == null) return false;
    return raceRunners!.any((runner) => runner is int);
  }

  /// Checks if there are any timing conflicts in the timing chunks
  bool containsTimingConflicts() {
    if (timingChunks == null) return false;

    return timingChunks!.any((chunk) =>
        chunk.hasConflict &&
        chunk.conflictRecord!.conflict!.type != ConflictType.confirmRunner);
  }
}
