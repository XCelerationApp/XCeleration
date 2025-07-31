import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/device_connection_service.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
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
  List<TimingDatum>? timingData;
  List<RaceRunner>? raceRunners;
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
    timingData = null;
    raceRunners = null;
    notifyListeners();
  }

  /// Loads saved results from the database
  Future<void> loadResults() async {
    final List<RaceResult> savedResults =
        await masterRace.results;

    if (savedResults.isNotEmpty) {
      results = savedResults;
      resultsLoaded = true;
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

  /// Processes data received from devices
  Future<void> processReceivedData(BuildContext context) async {
    String? bibRecordsData = devices.bibRecorder?.data;
    String? finishTimesData = devices.raceTimer?.data;
    Logger.d(
        'Bib records data: ${bibRecordsData != null ? "Available" : "Null"}');
    Logger.d(
        'Finish times data: ${finishTimesData != null ? "Available" : "Null"}');

    if (bibRecordsData != null && finishTimesData != null) {
      final List<BibDatum>? bibData = await BibDecodeUtils.decodeEncodedRunners(bibRecordsData, context);

      Logger.d('Loaded bib data: ${bibData?.length ?? 'null'}');

      raceRunners = bibData == null
          ? []
          : await Future.wait(
              bibData.map((bibDatum) async {
                final found = await masterRace.getRaceRunnerByBib(bibDatum.bib);
                if (found != null) {
                  return found;
                } else {
                  // Create a minimal RaceRunner with raceId and Runner with bib
                  return RaceRunner(
                    raceId: masterRace.raceId,
                    runner: Runner(bibNumber: bibDatum.bib),
                    team: Team(), // Provide a default/empty team if needed
                  );
                }
              }),
            );
      if (raceRunners!.isEmpty) {
        Logger.e('No race runners loaded');
        raceRunners = null;
      }

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      timingData = await TimingDecodeUtils.decodeEncodedTimingData(finishTimesData);

      Logger.d('Loaded timing data: ${timingData?.length ?? 0}');

      // Check if context is still mounted after second async operation
      if (!context.mounted) return;

      resultsLoaded = true;
      notifyListeners();

      await _ensureBibNumberAndRunnerRecordLengthsAreEqual();

      await _checkForConflictsAndSaveResults();
    } else {
      Logger.e(
        'Missing data source: bibRecordsData or finishTimesData is null');
    }
  }

  Future<void> _ensureBibNumberAndRunnerRecordLengthsAreEqual() async {
    if (raceRunners != null && timingData != null) {
      if (raceRunners!.length != timingData!.length) {
        Logger.d('Bib number and runner record lengths are not equal');
        int diff = raceRunners!.length - timingData!.length;
        Logger.d('Difference: $diff');
        if (diff > 0) {
          Logger.d('Removing $diff records from runnerRecords');
          timingData!.removeRange(timingData!.length - diff, timingData!.length);
        } else if (diff < 0) {
          Logger.d('Adding $diff records to timingData');
          timingData!.add(TimingDatum(
            time: 'EQUALIZING_MISSING_TIMES',
            conflict: Conflict(type: ConflictType.missingTime, offBy: diff.abs()),
          ));
        }
      // } else if (timingData!.last.type == RecordType.runnerTime) {
      //   Logger.d('Last record is a runner time');
      //   timingData!.records = confirmTimes(timingData!.records,
      //       timingData!.records.length, timingData!.endTime,
      //   );
      }
    }
  }

  Future<void> _checkForConflictsAndSaveResults() async {
    hasBibConflicts = containsBibConflicts();
    hasTimingConflicts = containsTimingConflicts();
    notifyListeners();

    if (!hasBibConflicts &&
        !hasTimingConflicts &&
        timingData != null &&
        raceRunners != null) {
      await _mergeBibDataWithTimingDataAndSaveResults();
      notifyListeners();
    }
  }

  /// Merges runner records with timing data
  Future<List<RaceResult>> _mergeBibDataWithTimingDataAndSaveResults() async {
    timingData = timingData?.where((record) => !record.hasConflict).toList();

    if (timingData == null || raceRunners == null) {
      Logger.e('Timing data or race runners is null');
      return [];
    }

    for (var i = 1; i <= timingData!.length; i++) {

      final raceRunner = raceRunners![i];
      final timingDatum = timingData![i];

      // Convert elapsed time string to Duration
      Duration finishDuration;
      finishDuration =
          TimeFormatter.loadDurationFromString(timingDatum.time) ??
              Duration.zero;

      final runner = raceRunner.runner;
      final team = raceRunner.team;

      masterRace.addResult(RaceResult(
        runner: runner,
        team: team,
        place: i,
        finishTime: finishDuration,
      ));
    }
    results = await masterRace.results;
    Logger.d('Data merged, created ${results.length} result records');
    return results;
  }

  /// Shows sheet for resolving bib conflicts
  Future<void> showBibConflictsSheet(BuildContext context) async {
    if (raceRunners == null) return;

    final List<RaceRunner>? updatedRaceRunners = await sheet(
      context: context,
      title: 'Resolve Bib Numbers',
      body: BibConflictsOverview(
        masterRace: masterRace,
        raceRunners: raceRunners!,
        onResolved: (updatedRaceRunners) {
          Navigator.pop(context, updatedRaceRunners);
        },
      ),
    );

    // Update runner records if a result was returned
    if (updatedRaceRunners != null) {
      raceRunners = updatedRaceRunners;
      await _checkForConflictsAndSaveResults();

      // If there are still timing conflicts, open the timing conflicts sheet
      if (hasTimingConflicts &&
          !hasBibConflicts &&
          timingData != null &&
          context.mounted) {
        await showTimingConflictsSheet(context);
      }
    }
  }

  /// Shows sheet for resolving timing conflicts
  Future<void> showTimingConflictsSheet(BuildContext context) async {
    if (timingData == null || raceRunners == null) return;

    final updatedTimingData = await sheet(
      context: context,
      title: 'Resolve Timing Conflicts',
      body: ChangeNotifierProvider(
        create: (_) => MergeConflictsController(
          masterRace: masterRace,
          timingChunks: timingChunksFromTimingData(timingData!),
          raceRunners: raceRunners!,
        ),
        child: MergeConflictsScreen(
          masterRace: masterRace,
          timingChunks: timingChunksFromTimingData(timingData!),
          raceRunners: raceRunners!,
        ),
      ),
      useBottomPadding: false,
    );

    // Update timing data if a result was returned
    if (updatedTimingData != null) {
      timingData = updatedTimingData;

      await _checkForConflictsAndSaveResults();
    }
  }

  /// Checks if there are any bib conflicts in the provided records
  bool containsBibConflicts() {
    return raceRunners?.any((raceRunner) => !raceRunner.isValid) ?? false;
  }

  /// Checks if there are any timing conflicts in the timing data
  bool containsTimingConflicts() {
    return timingData?.any((record) => record.hasConflict) ?? false;
  }
}
