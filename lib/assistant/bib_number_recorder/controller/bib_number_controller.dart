import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart' hide RunnerRecordFlags;
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/i_post_frame_scheduler.dart';
import '../../../core/services/text_input_factory.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/i_device_connection_factory.dart';
import '../../../core/utils/decode_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import '../model/bib_record.dart';
import '../../shared/models/race_record.dart';
import '../../shared/services/i_demo_race_generator.dart';
import '../../shared/models/bib_record.dart' as db_models;
import '../../shared/models/runner.dart' as db_models;
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import '../../shared/widgets/other_races_sheet.dart';
import '../widget/runners_loaded_sheet.dart';
import 'bib_number_data_controller.dart';

sealed class ShareDataResult {}

final class ShareDataDemoRace extends ShareDataResult {}

final class ShareDataHasDuplicates extends ShareDataResult {
  final List<String> duplicates;
  final bool hasUnknown;
  final String encodedData;
  ShareDataHasDuplicates({
    required this.duplicates,
    required this.hasUnknown,
    required this.encodedData,
  });
}

final class ShareDataHasUnknown extends ShareDataResult {
  final String encodedData;
  ShareDataHasUnknown({required this.encodedData});
}

final class ShareDataReady extends ShareDataResult {
  final String encodedData;
  ShareDataReady({required this.encodedData});
}

class BibNumberController extends BibNumberDataController {
  late final ScrollController scrollController;
  late final List<BibDatum> runners;

  final TutorialManager tutorialManager;
  final IDemoRaceGenerator _demoRaceGenerator;
  final IDeviceConnectionFactory _deviceConnectionFactory;
  final IPostFrameScheduler _scheduler;

  // Debounce timer for validations
  Timer? _debounceTimer;

  // Flag to notify screen that runners were just loaded (screen shows the sheet)
  bool _runnersJustLoaded = false;
  bool get runnersJustLoaded => _runnersJustLoaded;

  void clearRunnersJustLoaded() {
    _runnersJustLoaded = false;
  }

  BibNumberController({
    required super.storage,
    super.textInputFactory = const TextInputFactory(),
    required this.tutorialManager,
    required IDemoRaceGenerator demoRaceGenerator,
    required IDeviceConnectionFactory deviceConnectionFactory,
    required IPostFrameScheduler scheduler,
  })  : _demoRaceGenerator = demoRaceGenerator,
        _deviceConnectionFactory = deviceConnectionFactory,
        _scheduler = scheduler {
    runners = [];
    scrollController = ScrollController();
    _loadLastRace();
  }

  set raceStopped(bool value) {
    if (raceStopped == value) {
      return;
    }
    if (currentRace == null) {
      throw Exception('Race isn\'t loaded');
    }
    storage.updateRaceStatus(currentRace!.raceId, currentRace!.type, value);
    setRaceStopped(value);

    for (var node in focusNodes) {
      node.unfocus();
    }
    if (bibRecords.isNotEmpty) {
      if (bibRecords.last.bib.isEmpty) {
        bibRecords.removeLast();
      }
    }
    notifyListeners();
  }

  /// Sets the race stopped state without updating the database (used when loading races)
  void _setRaceStoppedState(bool value) {
    if (raceStopped == value) {
      return;
    }
    setRaceStopped(value);
  }

  bool isCurrentRaceDemoRace() {
    if (currentRace == null) return false;
    return _demoRaceGenerator.isDemoRace(currentRace!);
  }

  void setupTutorials() {
    tutorialManager
        .startTutorial(['race_header_tutorial', 'role_bar_tutorial']);
  }

  Future<void> _loadLastRace() async {
    // Ensure demo race exists if no races are present
    await _demoRaceGenerator.ensureDemoRaceExists(
        DeviceName.bibRecorder.toString());

    final result = await storage.getRaces(DeviceName.bibRecorder.toString());
    if (result case Success(:final value) when value.isNotEmpty) {
      await _loadRace(value.last);
    }
  }

  /// Loads runners from database for the current race
  Future<void> _loadRunners() async {
    if (currentRace == null) {
      return;
    }

    try {
      final List<db_models.Runner> dbRunners;
      switch (await storage.getRunners(currentRace!.raceId)) {
        case Success(:final value):
          dbRunners = value;
        case Failure(:final error):
          Logger.e(
              '[BibNumberController._loadRunners] ${error.originalException}');
          dbRunners = [];
      }

      // Clear existing runners and populate with loaded data
      runners.clear();
      for (final runner in dbRunners) {
        // Convert database Runner to BibDatum
        runners.add(BibDatum(
          bib: runner.bibNumber,
          name: runner.name,
          teamAbbreviation: runner.teamAbbreviation,
          grade: runner.grade,
          teamColor: runner.teamColor,
        ));
      }
    } catch (e) {
      Logger.e('Failed to load runners from database: $e');
    }
  }

  /// Loads bib records from database for the current race
  Future<void> _loadBibRecords() async {
    if (currentRace == null) {
      Logger.e('Cannot load bib records - no current race loaded');
      return;
    }

    try {
      final List<db_models.BibRecord> dbBibRecords;
      switch (await storage.getBibRecords(currentRace!.raceId)) {
        case Success(:final value):
          dbBibRecords = value;
        case Failure(:final error):
          Logger.e(
              '[BibNumberController._loadBibRecords] ${error.originalException}');
          return;
      }

      // Clear existing records
      clearBibRecords();

      // Convert database records to UI records
      for (final dbRecord in dbBibRecords) {
        // Create initial bib record
        final bibRecord = BibDatumRecord(
          bib: dbRecord.bibNumber,
          name: '',
          teamAbbreviation: '',
          grade: '',
          teamColor: null,
          flags: const BibDatumRecordFlags(
            notInDatabase: false,
            duplicateBibNumber: false,
          ),
        );

        // Add the bib record
        final index = await addBibRecord(bibRecord);

        // Validate it to populate runner info and set flags
        await validateBibNumber(index, dbRecord.bibNumber);
      }
    } catch (e) {
      Logger.e('Failed to load bib records from database: $e');
    }
  }

  /// Saves all current bib records to database
  Future<void> saveBibRecords() async {
    if (currentRace == null) return;
    await saveBibRecordsToDatabase(currentRace!.raceId);
  }

  /// Removes a single bib record from database
  Future<void> removeBibRecordFromDatabase(int index) async {
    if (currentRace == null) return;

    try {
      await storage.removeBibRecord(currentRace!.raceId, index);
    } catch (e) {
      Logger.e('Failed to remove bib record from database: $e');
    }
  }

  /// Shows other races sheet
  Future<void> showOtherRaces(BuildContext context) async {
    final result = await storage.getRaces(DeviceName.bibRecorder.toString());
    if (!context.mounted) return;
    final races = switch (result) {
      Success(:final value) => value,
      Failure() => <RaceRecord>[],
    };

    sheet(
      context: context,
      title: 'Other Races',
      body: OtherRacesSheet(
        races: races,
        currentRace: currentRace,
        onRaceSelected: loadOtherRace,
        role: DeviceName.bibRecorder,
      ),
    );
  }

  Future<void> _loadRace(RaceRecord raceRecord) async {
    // Set the current race
    setCurrentRace(raceRecord);

    // Set race state without updating database (we're loading from database)
    _setRaceStoppedState(raceRecord.stopped);

    // Load runners for this race first
    await _loadRunners();

    // Load bib records after runners are loaded
    await _loadBibRecords();

    // Final notification to update UI
    notifyListeners();
  }

  /// Loads a race with runners data (used when loading from coach)
  Future<void> _loadRaceWithRunners(
      RaceRecord raceRecord, List<BibDatum> runnersData) async {
    // Completely reset everything before loading new race
    _resetControllerState();

    // Set the current race
    setCurrentRace(raceRecord);

    // Set race state without updating database (we're loading from database)
    _setRaceStoppedState(raceRecord.stopped);

    // Set runners from provided data
    runners.addAll(runnersData);

    // Load bib records after runners are set
    await _loadBibRecords();

    // Final notification to update UI
    notifyListeners();

    // Notify screen that runners were loaded so it can show the sheet
    if (runners.isNotEmpty) {
      _runnersJustLoaded = true;
      notifyListeners();
    }
  }

  /// Completely resets the controller state before loading a new race
  void _resetControllerState() {
    // Clear current race
    setCurrentRace(null);

    // Reset race state
    setRaceStopped(true);

    // Clear runners list
    runners.clear();

    // Clear all bib records and dispose resources
    clearBibRecords();

    // Notify listeners of the reset
    notifyListeners();
  }

  /// Loads a previous race and its bib records
  Future<void> loadOtherRace(RaceRecord race) async {
    // Completely reset everything before loading new race
    _resetControllerState();

    // Load the new race
    await _loadRace(race);
  }

  /// Parses [data], saves the race and any runners to storage, then loads
  /// the race into the controller. Returns [Failure] with a user-readable
  /// message if parsing or saving fails.
  Future<Result<void>> processLoadedRaceData(String data) async {
    late RaceRecord raceRecord;
    List<BibDatum> loadedRunners = [];

    try {
      // Coach sends: raceData---runnerData (runners section is optional)
      final parts = data.split('---');
      if (parts.length == 2) {
        raceRecord = RaceRecord.fromEncodedString(parts[0],
            type: DeviceName.bibRecorder.toString());

        final runnersResult =
            await BibDecodeUtils.decodeEncodedRunners(parts[1]);
        switch (runnersResult) {
          case Success(:final value):
            loadedRunners = value;
          case Failure(:final error):
            Logger.e(
                '[BibNumberController.processLoadedRaceData] ${error.originalException}');
            return Failure(error);
        }
      } else {
        raceRecord = RaceRecord.fromEncodedString(data,
            type: DeviceName.bibRecorder.toString());
      }
    } catch (e) {
      Logger.e('Error parsing race data: $e');
      return Failure(AppError(userMessage: 'Failed to parse race data: $e'));
    }

    final saveResult = await storage.saveNewRace(raceRecord);
    if (saveResult case Failure(:final error)) {
      Logger.e(
          '[BibNumberController.processLoadedRaceData] ${error.originalException}');
      return Failure(error);
    }

    if (loadedRunners.isNotEmpty) {
      final dbRunners = loadedRunners
          .map((runner) => db_models.Runner(
                raceId: raceRecord.raceId,
                bibNumber: runner.bib,
                name: runner.name,
                teamAbbreviation: runner.teamAbbreviation,
                grade: runner.grade,
                teamColor: runner.teamColor,
                createdAt: DateTime.now(),
              ))
          .toList();
      await storage.saveRunners(raceRecord.raceId, dbRunners);
    }

    clearBibRecords();
    await _loadRaceWithRunners(raceRecord, loadedRunners);
    return const Success(null);
  }

  Future<void> showLoadRaceSheet(BuildContext context) async {
    final devices = _deviceConnectionFactory.createDevices(
      DeviceName.bibRecorder,
      DeviceType.browserDevice,
    );
    sheet(
      context: context,
      title: 'Load Race',
      body: deviceConnectionWidget(
        context,
        devices,
        callback: () async {
          final data = devices.coach?.data;
          if (data == null) {
            DialogUtils.showErrorDialog(context,
                message: 'Race data not received');
            return;
          }
          final result = await processLoadedRaceData(data);
          if (result case Failure(:final error) when context.mounted) {
            DialogUtils.showErrorDialog(context, message: error.userMessage);
          }
        },
      ),
    );
  }

  /// Deletes the current race
  Future<void> deleteCurrentRace() async {
    if (currentRace == null) return;

    final result =
        await storage.deleteRace(currentRace!.raceId, currentRace!.type);
    if (result case Failure(:final error)) {
      Logger.e(
          '[BibNumberController.deleteCurrentRace] ${error.originalException}');
      return;
    }
    setCurrentRace(null);
    clearBibRecords();
    notifyListeners();
  }

  void showShareBibNumbersSheet(BuildContext context, String encodedData) {
    sheet(
      context: context,
      title: 'Share Bib Numbers',
      body: deviceConnectionWidget(
        context,
        _deviceConnectionFactory.createDevices(
          DeviceName.bibRecorder,
          DeviceType.advertiserDevice,
          data: encodedData,
        ),
      ),
    );
  }

  void showRunnersLoadedSheet(BuildContext context) {
    sheet(
      context: context,
      title: 'Loaded Runners',
      body: RunnersLoadedSheet(runners: runners),
    );
  }

  /// Gets a runner by bib number from the local runners list
  BibDatum? getRunnerByBib(String bib) {
    for (final runner in runners) {
      if (runner.bib == bib) {
        return runner;
      }
    }
    return null;
  }

  // Bib number validation and handling
  Future<void> validateBibNumber(int index, String bibNumber) async {
    if (index < 0 || index >= bibRecords.length) {
      return;
    }

    // Special handling for empty inputs
    if (bibNumber.isEmpty) {
      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: const BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: false,
        ),
      );
      updateBibRecord(index, updatedRecord);
      return;
    }

    // Try to parse the bib number
    if (!bibNumber.contains(RegExp(r'^[0-9]+$'))) {
      // Not a valid number
      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: BibDatumRecordFlags(
          notInDatabase: true,
          duplicateBibNumber: false,
        ),
      );
      updateBibRecord(index, updatedRecord);
      return;
    }

    // Check for a matching runner
    BibDatum? matchedRunner = getRunnerByBib(bibNumber);

    if (matchedRunner != null) {
      // Found a match in database
      // Check for duplicate entries
      bool isDuplicate = false;
      int count = 0;
      for (var i = 0; i < bibRecords.length; i++) {
        if (bibRecords[i].bib == bibNumber) {
          count++;
          if (count > 1 && i == index) {
            isDuplicate = true;
            break;
          }
        }
      }

      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: matchedRunner.name,
        teamAbbreviation: matchedRunner.teamAbbreviation,
        grade: matchedRunner.grade,
        teamColor: matchedRunner.teamColor,
        flags: BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: isDuplicate,
        ),
      );
      updateBibRecord(index, updatedRecord);
    } else {
      // No match in database
      final updatedRecord = BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: BibDatumRecordFlags(
          notInDatabase: true,
          duplicateBibNumber: false,
        ),
      );
      updateBibRecord(index, updatedRecord);
    }
  }

  Future<void> addBib() async {
    if (bibRecords.isEmpty || bibRecords.last.bib.isNotEmpty) {
      await handleBibNumber('');
      focusNodes.last.requestFocus();
    } else {
      focusNodes.last.requestFocus();
    }
  }

  /// Handles bib number changes with optimizations to prevent UI jumping
  Future<void> handleBibNumber(
    String bibNumber, {
    int? index,
  }) async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    if (index != null) {
      // Update existing record (immediately update the text but debounce validation)
      if (index < bibRecords.length) {
        final record = bibRecords[index];

        // Update text immediately without revalidating
        final updatedRecord = record.copyWith(bib: bibNumber);
        updateBibRecord(index, updatedRecord);

        // Debounce the validation to prevent rapid UI updates while typing
        _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
          await validateBibNumber(index, bibNumber);
        });
      }
    } else {
      // Add new record
      addBibRecord(BibDatumRecord(
        bib: bibNumber,
        name: '',
        teamAbbreviation: '',
        grade: '',
        flags: const BibDatumRecordFlags(
          notInDatabase: false,
          duplicateBibNumber: false,
        ),
      ));

      // Only scroll if necessary - check if we need to scroll to make new item visible
      _scheduler.schedulePostFrame(_scrollToLastItemIfNeeded);

      // Validate the new record and revalidate all others for duplicate state
      // in a single timer to avoid the triple-assignment bug
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        final newIndex = bibRecords.length - 1;
        if (newIndex >= 0) {
          await validateBibNumber(newIndex, bibNumber);
        }
        for (var i = 0; i < bibRecords.length - 1; i++) {
          await validateBibNumber(i, bibRecords[i].bib);
        }
      });

      // Safely determine focus index for new additions
      final focusIndex = bibRecords.length - 1;

      // Only request focus if the index is valid
      if (focusIndex >= 0 && focusIndex < focusNodes.length) {
        // Request focus after a slight delay to allow the UI to settle
        _scheduler.schedulePostFrame(() => focusNodes[focusIndex].requestFocus());
      }
    }
  }

  /// Only scrolls when the last item isn't already visible
  void _scrollToLastItemIfNeeded() {
    // Only attempt to scroll if we have a non-empty list and a valid scroll controller
    if (bibRecords.isEmpty || !scrollController.hasClients) return;

    // Check if we're already near the bottom
    final position = scrollController.position;
    final viewportDimension = position.viewportDimension;
    final maxScrollExtent = position.maxScrollExtent;
    final currentOffset = position.pixels;

    // If we're not already seeing the bottom part of the list, scroll to make new item visible
    if (maxScrollExtent > 0 &&
        (maxScrollExtent - currentOffset) > (viewportDimension / 2)) {
      scrollController.animateTo(
        maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  /// Validates bib records and encodes share data, returning a typed result.
  /// The screen should show dialogs based on the result and call
  /// [showShareBibNumbersSheet] with the encoded data on user confirmation.
  Future<ShareDataResult> prepareShareData() async {
    if (isCurrentRaceDemoRace()) {
      return ShareDataDemoRace();
    }

    await cleanEmptyRecords();

    final duplicates = checkDuplicateRecords();
    if (duplicates.isNotEmpty) {
      final encodedData = await getEncodedBibData();
      return ShareDataHasDuplicates(
        duplicates: duplicates,
        hasUnknown: checkUnknownRecords(),
        encodedData: encodedData,
      );
    }

    if (checkUnknownRecords()) {
      final encodedData = await getEncodedBibData();
      return ShareDataHasUnknown(encodedData: encodedData);
    }

    final encodedData = await getEncodedBibData();
    return ShareDataReady(encodedData: encodedData);
  }

  @override
  void dispose() {
    // Cancel timer first before any other cleanup
    _debounceTimer?.cancel();

    // Dispose of tutorial manager
    tutorialManager.dispose();

    // Dispose of scroll controller
    if (scrollController.hasClients) {
      scrollController.dispose();
    }
    super.dispose();
  }
}
