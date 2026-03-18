import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/i_text_input_factory.dart';
import '../model/bib_datum_record.dart';
import '../../shared/models/race_record.dart';
import '../../shared/services/i_assistant_storage_service.dart';
import '../../shared/models/bib_record.dart' as db_models;
import '../../shared/models/runner.dart' as db_models;

class BibNumberDataController extends ChangeNotifier {
  final List<BibDatumRecord> _bibRecords = [];
  final List<TextEditingController> controllers = [];
  final List<FocusNode> focusNodes = [];

  /// Per-row notifiers so each [BibInputWidget] can rebuild independently
  /// without triggering a full-list rebuild.
  final List<ValueNotifier<BibDatumRecord>> _rowNotifiers = [];

  /// Stored listener closures parallel to [focusNodes] so [removeListener]
  /// can receive the exact same object that was passed to [addListener].
  /// An anonymous `() {}` passed to [removeListener] is a new object and
  /// never matches the original, making the call a no-op.
  final List<VoidCallback> _focusListeners = [];
  List<ValueNotifier<BibDatumRecord>> get rowNotifiers => _rowNotifiers;

  /// Narrow notifier for the current race so [RaceHeaderWidget] only rebuilds
  /// when the race itself changes, not on every keystroke.
  final ValueNotifier<RaceRecord?> currentRaceNotifier = ValueNotifier(null);

  /// Tracks keyboard visibility without going through the main [notifyListeners]
  /// path. Widgets that only need keyboard state (e.g. [KeyboardAccessoryBar])
  /// can listen to this notifier directly and avoid rebuilding on every
  /// unrelated controller change.
  final ValueNotifier<bool> keyboardVisibleNotifier = ValueNotifier(false);

  // Race context and storage - single source of truth
  final IAssistantStorageService storage;
  final ITextInputFactory _textInputFactory;
  RaceRecord? _currentRace;
  bool _raceStopped = true;

  BibNumberDataController({
    required this.storage,
    required ITextInputFactory textInputFactory,
  }) : _textInputFactory = textInputFactory;

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

      for (var i = 0; i < focusNodes.length; i++) {
        if (i < _focusListeners.length) {
          focusNodes[i].removeListener(_focusListeners[i]);
        }
        focusNodes[i].dispose();
      }
      focusNodes.clear();
      _focusListeners.clear();

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
    _rowNotifiers.add(ValueNotifier(record));

    final newIndex = _bibRecords.length - 1;
    final controller = _textInputFactory.createController(record.bib);
    controllers.add(controller);

    final focusNode = _textInputFactory.createFocusNode();
    void focusListener() {
      keyboardVisibleNotifier.value = focusNode.hasFocus;
      if (!focusNode.hasFocus) {
        _saveBibRecordOnFocusLoss(newIndex);
      }
    }
    focusNode.addListener(focusListener);
    _focusListeners.add(focusListener);
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
    if (index < _rowNotifiers.length) _rowNotifiers[index].value = record;

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

    if (index < _focusListeners.length) {
      focusNodes[index].removeListener(_focusListeners[index]);
      _focusListeners.removeAt(index);
    }
    focusNodes[index].dispose();
    focusNodes.removeAt(index);

    if (index < _rowNotifiers.length) {
      _rowNotifiers[index].dispose();
      _rowNotifiers.removeAt(index);
    }

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

    for (var i = 0; i < focusNodes.length; i++) {
      if (i < _focusListeners.length) {
        focusNodes[i].removeListener(_focusListeners[i]);
      }
      focusNodes[i].dispose();
    }
    focusNodes.clear();
    _focusListeners.clear();

    for (var notifier in _rowNotifiers) {
      notifier.dispose();
    }
    _rowNotifiers.clear();

    notifyListeners();
  }

  /// Sets the current race
  void setCurrentRace(RaceRecord? race) {
    _currentRace = race;
    currentRaceNotifier.value = race;
    notifyListeners();
  }

  /// Sets the race stopped state
  void setRaceStopped(bool stopped) {
    _raceStopped = stopped;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Batch / silent helpers — no notifyListeners(); caller notifies once at end.
  // ---------------------------------------------------------------------------

  /// Adds a bib record without notifying listeners. Returns the new index.
  /// Use only inside bulk-load operations that emit a single notification at
  /// the end (e.g. [_loadBibRecords]).
  int addBibRecordSilent(BibDatumRecord record) {
    _bibRecords.add(record);
    _rowNotifiers.add(ValueNotifier(record));
    final newIndex = _bibRecords.length - 1;
    controllers.add(_textInputFactory.createController(record.bib));

    final focusNode = _textInputFactory.createFocusNode();
    void focusListener() {
      keyboardVisibleNotifier.value = focusNode.hasFocus;
      if (!focusNode.hasFocus) {
        _saveBibRecordOnFocusLoss(newIndex);
      }
    }
    focusNode.addListener(focusListener);
    _focusListeners.add(focusListener);
    focusNodes.add(focusNode);
    return newIndex;
  }

  /// Updates a bib record without notifying listeners.
  /// Use only inside bulk-load operations.
  void updateBibRecordSilent(int index, BibDatumRecord record) {
    if (index < 0 || index >= _bibRecords.length) return;
    _bibRecords[index] = record;
    if (index < _rowNotifiers.length) _rowNotifiers[index].value = record;
    if (index < controllers.length) {
      final currentText = controllers[index].text;
      if (currentText != record.bib) controllers[index].text = record.bib;
    }
  }

  /// Clears only the bib record list (and its controllers/focus nodes) without
  /// notifying listeners. Use inside [_loadBibRecords] to avoid mid-load rebuilds.
  void clearBibRecordsSilent() {
    _bibRecords.clear();
    for (var c in controllers) {
      c.dispose();
    }
    controllers.clear();
    for (var i = 0; i < focusNodes.length; i++) {
      if (i < _focusListeners.length) {
        focusNodes[i].removeListener(_focusListeners[i]);
      }
      focusNodes[i].dispose();
    }
    focusNodes.clear();
    _focusListeners.clear();
    for (var notifier in _rowNotifiers) {
      notifier.dispose();
    }
    _rowNotifiers.clear();
  }

  /// Resets all mutable UI state (race, stopped flag, bib records) without
  /// notifying listeners. Caller must call [notifyListeners] once the full
  /// reset + load sequence completes.
  void resetStateForLoad() {
    _currentRace = null;
    currentRaceNotifier.value = null;
    _raceStopped = true;
    clearBibRecordsSilent();
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
    // Dispose of focus nodes — remove the stored listener reference first so
    // focus events that fire during teardown cannot call notifyListeners() on
    // the partially-disposed controller.
    for (var i = 0; i < focusNodes.length; i++) {
      try {
        if (i < _focusListeners.length) {
          focusNodes[i].removeListener(_focusListeners[i]);
        }
        focusNodes[i].dispose();
      } catch (e) {
        Logger.e('Warning: Error disposing focus node: $e');
      }
    }
    _focusListeners.clear();

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
    for (var notifier in _rowNotifiers) {
      notifier.dispose();
    }
    _rowNotifiers.clear();
    currentRaceNotifier.dispose();
    keyboardVisibleNotifier.dispose();
    super.dispose();
  }
}
