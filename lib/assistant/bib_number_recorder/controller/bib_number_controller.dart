import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart' hide RunnerRecordFlags;
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/i_device_connection_factory.dart';
import '../../../core/utils/decode_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import '../model/bib_record.dart';
import '../../shared/models/race_record.dart';
import '../../shared/services/i_assistant_storage_service.dart';
import '../../shared/services/i_demo_race_generator.dart';
import '../../shared/models/bib_record.dart' as db_models;
import '../../shared/models/runner.dart' as db_models;
import 'package:xceleration/core/result.dart';
import '../../shared/widgets/other_races_sheet.dart';
import '../widget/runners_loaded_sheet.dart';

class BibNumberController extends BibNumberDataController {
  late final ScrollController scrollController;
  late final List<BibDatum> runners;

  final TutorialManager tutorialManager;
  final IDemoRaceGenerator _demoRaceGenerator;
  final IDeviceConnectionFactory _deviceConnectionFactory;

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
    required this.tutorialManager,
    required IDemoRaceGenerator demoRaceGenerator,
    required IDeviceConnectionFactory deviceConnectionFactory,
  })  : _demoRaceGenerator = demoRaceGenerator,
        _deviceConnectionFactory = deviceConnectionFactory {
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
    if (_bibRecords.isNotEmpty) {
      if (_bibRecords.last.bib.isEmpty) {
        _bibRecords.removeLast();
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
    _raceStopped = true;

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
          late RaceRecord raceRecord;
          List<BibDatum> runners = [];
          try {
            // Split the data - coach sends: raceData---runnerData
            final parts = data.split('---');
            if (parts.length == 2) {
              // Decode race data
              raceRecord = RaceRecord.fromEncodedString(parts[0],
                  type: DeviceName.bibRecorder.toString());

              // Decode runner data
              final runnersResult =
                  await BibDecodeUtils.decodeEncodedRunners(parts[1]);
              switch (runnersResult) {
                case Success(:final value):
                  runners = value;
                case Failure(:final error):
                  Logger.e(
                      '[BibNumberController.showLoadRaceSheet] ${error.originalException}');
                  return;
              }
            } else {
              // Fallback: try to decode as race data only
              raceRecord = RaceRecord.fromEncodedString(data,
                  type: DeviceName.bibRecorder.toString());
            }
          } catch (e) {
            Logger.e('Error parsing race data: $e');
            if (context.mounted) {
              DialogUtils.showErrorDialog(context,
                  message: 'Failed to parse race data: $e');
            }
            return;
          }
          final saveResult = await storage.saveNewRace(raceRecord);
          if (saveResult case Failure(:final error)) {
            Logger.e(
                '[BibNumberController.showLoadRaceSheet] ${error.originalException}');
            if (context.mounted) {
              DialogUtils.showErrorDialog(context, message: error.userMessage);
            }
            return;
          }

          // Save runners to database
          if (runners.isNotEmpty) {
            final dbRunners = runners
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
          _loadRaceWithRunners(raceRecord, runners);
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
    if (index < 0 || index >= _bibRecords.length) {
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
      if (index < _bibRecords.length) {
        final record = _bibRecords[index];

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLastItemIfNeeded();
      });

      // After adding a new record, we don't need to immediately validate
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        final newIndex = _bibRecords.length - 1;
        if (newIndex >= 0) {
          await validateBibNumber(newIndex, bibNumber);
        }
      });
    }

    // We don't want to revalidate all items on every keystroke
    // Only do this on explicit user actions like adding/removing items
    if (index == null) {
      // Validate all bib numbers to update duplicate states after a delay
      _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
        for (var i = 0; i < _bibRecords.length; i++) {
          if (i != index) {
            // Skip the one we're currently editing
            await validateBibNumber(i, _bibRecords[i].bib);
          }
        }
      });
    }

    if (index == null) {
      // Safely determine focus index for new additions
      final focusIndex = _bibRecords.length - 1;

      // Only request focus if the index is valid
      if (focusIndex >= 0 && focusIndex < focusNodes.length) {
        // Request focus after a slight delay to allow the UI to settle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          focusNodes[focusIndex].requestFocus();
        });
      }
    }
  }

  /// Only scrolls when the last item isn't already visible
  void _scrollToLastItemIfNeeded() {
    // Only attempt to scroll if we have a non-empty list and a valid scroll controller
    if (_bibRecords.isEmpty || !scrollController.hasClients) return;

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

class BibNumberDataController extends ChangeNotifier {
  final List<BibDatumRecord> _bibRecords = [];
  final List<TextEditingController> controllers = [];
  final List<FocusNode> focusNodes = [];

  bool _isKeyboardVisible = false;

  // Race context and storage - single source of truth
  final IAssistantStorageService storage;
  RaceRecord? _currentRace;
  bool _raceStopped = true;

  BibNumberDataController({required this.storage});

  bool get isKeyboardVisible => _isKeyboardVisible;

  set isKeyboardVisible(bool visible) {
    _isKeyboardVisible = visible;
    notifyListeners();
  }

  // Race context getters
  RaceRecord? get currentRace => _currentRace;
  bool get raceStopped => _raceStopped;

  List<BibDatumRecord> get bibRecords => _bibRecords;

  bool get canAddBib {
    if (_bibRecords.isEmpty) return true;
    final BibDatumRecord lastBib = _bibRecords.last;
    // Only prevent adding if the last bib is completely empty AND has focus
    // If the last bib has content (even if runner not found), allow adding
    if (lastBib.bib.isEmpty && focusNodes.last.hasPrimaryFocus) return false;
    return true;
  }

  // Synchronizes collections to match bibRecords length
  void _syncCollections() {
    // If collections are out of sync, reset them
    if (!(_bibRecords.length == controllers.length &&
        controllers.length == focusNodes.length)) {
      // Save existing bib records
      final existingRecords = List<BibDatumRecord>.from(_bibRecords);

      // Clear and dispose all existing controllers and focus nodes
      for (var controller in controllers) {
        if (controller.hasListeners) {
          controller.dispose();
        }
      }
      controllers.clear();

      for (var node in focusNodes) {
        node.dispose();
      }
      focusNodes.clear();

      // Reset records collection
      _bibRecords.clear();

      // Re-add all records with fresh controllers and focus nodes
      for (var record in existingRecords) {
        addBibRecord(record);
      }
    }
  }

  /// Adds a new bib record with the specified runner record.
  /// Returns the index of the added record.
  Future<int> addBibRecord(BibDatumRecord record) async {
    _bibRecords.add(record);

    final newIndex = _bibRecords.length - 1;
    final controller = TextEditingController(text: record.bib);
    controllers.add(controller);

    final focusNode = FocusNode();
    focusNode.addListener(() {
      // Handle keyboard visibility
      if (focusNode.hasFocus != _isKeyboardVisible) {
        _isKeyboardVisible = focusNode.hasFocus;
        notifyListeners();
      }

      // Save to database when focus is lost
      if (!focusNode.hasFocus) {
        _saveBibRecordOnFocusLoss(newIndex);
      }
    });
    focusNodes.add(focusNode);

    notifyListeners();
    return newIndex;
  }

  /// Saves a bib record to the database when focus is lost
  void _saveBibRecordOnFocusLoss(int index) async {
    if (index < 0 || index >= _bibRecords.length) return;

    final record = _bibRecords[index];
    final bibValue = record.bib;

    if (_currentRace != null && bibValue.isNotEmpty) {
      // Check if this bib record already exists in the database
      final getBibResult = await storage.getBibRecord(
        _currentRace!.raceId,
        index,
      );
      switch (getBibResult) {
        case Success(:final value) when value == null:
          // This is a new bib record, add it to database
          await storage.addBibRecord(_currentRace!.raceId, index, bibValue);
        case Success():
          // This is an existing bib record, update it in database
          await storage.updateBibRecordValue(
              _currentRace!.raceId, index, bibValue);
        case Failure(:final error):
          Logger.e(
              '[BibNumberController._saveBibRecordOnFocusLoss] ${error.originalException}');
      }
    } else {
      return;
    }
  }

  /// Updates an existing bib record at the specified index.
  void updateBibRecord(int index, BibDatumRecord record) {
    if (index < 0 || index >= _bibRecords.length) return;

    // Ensure collections are in sync
    _syncCollections();

    _bibRecords[index] = record;

    // Only update the controller text if it differs to avoid cursor jumping
    if (index < controllers.length) {
      final currentText = controllers[index].text;
      if (currentText != record.bib) {
        controllers[index].text = record.bib;
      }
    }

    notifyListeners();
  }

  /// Removes a bib record at the specified index.
  Future<void> removeBibRecord(int index) async {
    if (index < 0 || index >= _bibRecords.length) return;

    // Ensure collections are in sync before removing
    _syncCollections();

    if (index >= controllers.length || index >= focusNodes.length) return;

    _bibRecords.removeAt(index);

    // Clean up resources
    controllers[index].dispose();
    controllers.removeAt(index);

    focusNodes[index].dispose();
    focusNodes.removeAt(index);

    // Remove from database if there's a current race
    if (_currentRace != null) {
      try {
        await storage.removeBibRecord(_currentRace!.raceId, index);
      } catch (e) {
        Logger.e('Failed to remove bib record from database: $e');
      }
    } else {
      return;
    }

    notifyListeners();
  }

  void clearBibRecords() {
    _bibRecords.clear();

    // Dispose all controllers and focus nodes
    for (var controller in controllers) {
      controller.dispose();
    }
    controllers.clear();

    for (var node in focusNodes) {
      node.dispose();
    }
    focusNodes.clear();

    notifyListeners();
  }

  /// Sets the current race
  void setCurrentRace(RaceRecord? race) {
    _currentRace = race;
    notifyListeners();
  }

  /// Sets the race stopped state
  void setRaceStopped(bool stopped) {
    _raceStopped = stopped;

    notifyListeners();
  }

  /// Saves all current bib records to database
  Future<void> saveBibRecordsToDatabase(int raceId) async {
    try {
      final dbBibRecords = <db_models.BibRecord>[];
      final dbRunners = <db_models.Runner>[];
      int bibId = 0;

      for (final record in _bibRecords) {
        if (record.bib.isNotEmpty) {
          // Save bib record
          dbBibRecords.add(db_models.BibRecord(
            raceId: raceId,
            bibId: bibId++,
            bibNumber: record.bib,
            createdAt: DateTime.now(),
          ));

          // Save runner data if we have it
          if ((record.name?.isNotEmpty ?? false) ||
              (record.teamAbbreviation?.isNotEmpty ?? false) ||
              (record.grade?.isNotEmpty ?? false)) {
            dbRunners.add(db_models.Runner(
              raceId: raceId,
              bibNumber: record.bib,
              name: (record.name?.isNotEmpty ?? false) ? record.name : null,
              teamAbbreviation: (record.teamAbbreviation?.isNotEmpty ?? false)
                  ? record.teamAbbreviation
                  : null,
              grade: (record.grade?.isNotEmpty ?? false) ? record.grade : null,
              teamColor: record.teamColor,
              createdAt: DateTime.now(),
            ));
          }
        }
      }

      await storage.saveBibRecords(raceId, dbBibRecords);
      if (dbRunners.isNotEmpty) {
        await storage.saveRunners(raceId, dbRunners);
      }
    } catch (e) {
      Logger.e('Failed to save bib records: $e');
    }
  }

  /// Restores the focus abilities for all focus nodes
  void restoreFocusability() {
    for (var node in focusNodes) {
      node.canRequestFocus = true;
    }
  }

  /// Gets the encoded bib data for sharing
  Future<String> getEncodedBibData() async {
    return await BibEncodeUtils.getEncodedBibData(_bibRecords);
  }

  /// Returns all unique bib numbers and the corresponding runner records
  Map<String, BibDatumRecord> getBibsAndRunners() {
    final map = <String, BibDatumRecord>{};
    for (final record in _bibRecords) {
      if (record.bib.isNotEmpty) {
        map[record.bib] = record;
      }
    }
    return map;
  }

  /// Returns duplicate bib numbers (empty list means no duplicates).
  List<String> checkDuplicateRecords() {
    final duplicates = <String>[];
    final seen = <String>{};

    for (final record in _bibRecords) {
      final bib = record.bib;
      if (bib.isEmpty) continue;

      if (seen.contains(bib)) {
        duplicates.add(bib);
      } else {
        seen.add(bib);
      }
    }

    return duplicates;
  }

  /// Returns true if any bib record is not in the database.
  bool checkUnknownRecords() {
    return _bibRecords.any((record) => record.flags.notInDatabase);
  }

  Future<bool> cleanEmptyRecords() async {
    final emptyRecords = _bibRecords.where((bib) => bib.bib.isEmpty).toList();

    for (var i = emptyRecords.length - 1; i >= 0; i--) {
      final index = _bibRecords.indexOf(emptyRecords[i]);
      if (index >= 0) {
        removeBibRecord(index);
      }
    }
    return true;
  }

  // Helper to check if we have any non-empty bib numbers
  bool hasNonEmptyBibNumbers() {
    return _bibRecords.any((record) => record.bib.isNotEmpty);
  }

  // Helper to count non-empty bib numbers
  int countNonEmptyBibNumbers() {
    return _bibRecords.where((bib) => bib.bib.isNotEmpty).length;
  }

  // Helper to count empty bib numbers
  int countEmptyBibNumbers() {
    return _bibRecords.where((bib) => bib.bib.isEmpty).length;
  }

  // Helper to count duplicate bib numbers
  int countDuplicateBibNumbers() {
    return _bibRecords
        .where((bib) => bib.flags.duplicateBibNumber == true)
        .length;
  }

  // Helper to count unknown bib numbers
  int countUnknownBibNumbers() {
    return _bibRecords.where((bib) => bib.flags.notInDatabase == true).length;
  }

  @override
  void dispose() {
    // Dispose of focus nodes
    for (var node in focusNodes) {
      try {
        // Try to remove listeners first to prevent callbacks during dispose
        node.removeListener(() {});
        node.dispose();
      } catch (e) {
        // Node may already be disposed, ignore the error
        Logger.e('Warning: Error disposing focus node: $e');
      }
    }

    // Dispose of text controllers
    for (var controller in controllers) {
      try {
        controller.dispose();
      } catch (e) {
        // Controller may already be disposed, ignore the error
        Logger.e('Warning: Error disposing text controller: $e');
      }
    }

    // Clear collections but don't notify listeners since we're disposing
    _bibRecords.clear();
    controllers.clear();
    focusNodes.clear();
    super.dispose();
  }
}
