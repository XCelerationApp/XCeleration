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

/// Bundles the five per-row resources that previously lived in five parallel
/// lists. Disposing a row cleans up all of its resources in one place.
class _BibRow {
  BibDatumRecord record;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback focusListener;
  final ValueNotifier<BibDatumRecord> notifier;

  _BibRow({
    required this.record,
    required this.controller,
    required this.focusNode,
    required this.focusListener,
    required this.notifier,
  });

  void dispose() {
    focusNode.removeListener(focusListener);
    focusNode.dispose();
    controller.dispose();
    notifier.dispose();
  }
}

class BibNumberDataController extends ChangeNotifier {
  final List<_BibRow> _rows = [];

  // ---------------------------------------------------------------------------
  // Public list views — computed from _rows so callers see a consistent API.
  // ---------------------------------------------------------------------------

  List<BibDatumRecord> get bibRecords => _rows.map((r) => r.record).toList();
  List<TextEditingController> get controllers =>
      _rows.map((r) => r.controller).toList();
  List<FocusNode> get focusNodes => _rows.map((r) => r.focusNode).toList();

  /// Per-row notifiers so each [BibInputWidget] can rebuild independently
  /// without triggering a full-list rebuild.
  List<ValueNotifier<BibDatumRecord>> get rowNotifiers =>
      _rows.map((r) => r.notifier).toList();

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

  bool get canAddBib {
    if (_rows.isEmpty) return true;
    final lastRow = _rows.last;
    // Only prevent adding if the last bib is completely empty AND has focus
    // If the last bib has content (even if runner not found), allow adding
    if (lastRow.record.bib.isEmpty && lastRow.focusNode.hasPrimaryFocus) {
      return false;
    }
    return true;
  }

  /// Adds a new bib record with the specified runner record.
  /// Returns the index of the added record.
  Future<int> addBibRecord(BibDatumRecord record) async {
    final index = addBibRecordSilent(record);
    notifyListeners();
    return index;
  }

  /// Saves a bib record to the database when focus is lost
  void _saveBibRecordOnFocusLoss(int index) async {
    if (index < 0 || index >= _rows.length) return;

    final record = _rows[index].record;
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
    if (index < 0 || index >= _rows.length) return;

    _rows[index].record = record;
    _rows[index].notifier.value = record;

    // Only update the controller text if it differs to avoid cursor jumping
    final currentText = _rows[index].controller.text;
    if (currentText != record.bib) {
      _rows[index].controller.text = record.bib;
    }

    notifyListeners();
  }

  /// Removes a bib record at the specified index.
  Future<void> removeBibRecord(int index) async {
    if (index < 0 || index >= _rows.length) return;

    _rows[index].dispose();
    _rows.removeAt(index);

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
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
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
    final newIndex = _rows.length;

    final controller = _textInputFactory.createController(record.bib);
    final focusNode = _textInputFactory.createFocusNode();
    void focusListener() {
      keyboardVisibleNotifier.value = focusNode.hasFocus;
      if (!focusNode.hasFocus) {
        _saveBibRecordOnFocusLoss(newIndex);
      }
    }

    focusNode.addListener(focusListener);

    _rows.add(_BibRow(
      record: record,
      controller: controller,
      focusNode: focusNode,
      focusListener: focusListener,
      notifier: ValueNotifier(record),
    ));

    return newIndex;
  }

  /// Updates a bib record without notifying listeners.
  /// Use only inside bulk-load operations.
  void updateBibRecordSilent(int index, BibDatumRecord record) {
    if (index < 0 || index >= _rows.length) return;
    _rows[index].record = record;
    _rows[index].notifier.value = record;
    final currentText = _rows[index].controller.text;
    if (currentText != record.bib) _rows[index].controller.text = record.bib;
  }

  /// Removes the last bib record without notifying listeners or touching the
  /// database. Use in synchronous contexts where DB removal is handled
  /// separately (e.g. [BibNumberController.raceStopped] setter).
  void removeLastBibRecordSilent() {
    if (_rows.isEmpty) return;
    _rows.last.dispose();
    _rows.removeLast();
  }

  /// Clears only the bib record list (and its controllers/focus nodes) without
  /// notifying listeners. Use inside [_loadBibRecords] to avoid mid-load rebuilds.
  void clearBibRecordsSilent() {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
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

      for (final row in _rows) {
        final record = row.record;
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
              grade:
                  (record.grade?.isNotEmpty ?? false) ? record.grade : null,
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
    for (final row in _rows) {
      row.focusNode.canRequestFocus = true;
    }
  }

  /// Gets the encoded bib data for sharing
  Future<String> getEncodedBibData() async {
    return await BibEncodeUtils.getEncodedBibData(
        _rows.map((r) => r.record).toList());
  }

  /// Returns all unique bib numbers and the corresponding runner records
  Map<String, BibDatumRecord> getBibsAndRunners() {
    final map = <String, BibDatumRecord>{};
    for (final row in _rows) {
      if (row.record.bib.isNotEmpty) {
        map[row.record.bib] = row.record;
      }
    }
    return map;
  }

  /// Returns duplicate bib numbers (empty list means no duplicates).
  List<String> checkDuplicateRecords() {
    final duplicates = <String>[];
    final seen = <String>{};

    for (final row in _rows) {
      final bib = row.record.bib;
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
    return _rows.any((row) => row.record.flags.notInDatabase);
  }

  Future<bool> cleanEmptyRecords() async {
    // Iterate in reverse to preserve indices while removing
    for (var i = _rows.length - 1; i >= 0; i--) {
      if (_rows[i].record.bib.isEmpty) {
        removeBibRecord(i);
      }
    }
    return true;
  }

  // Helper to check if we have any non-empty bib numbers
  bool hasNonEmptyBibNumbers() {
    return _rows.any((row) => row.record.bib.isNotEmpty);
  }

  // Helper to count non-empty bib numbers
  int countNonEmptyBibNumbers() {
    return _rows.where((row) => row.record.bib.isNotEmpty).length;
  }

  // Helper to count empty bib numbers
  int countEmptyBibNumbers() {
    return _rows.where((row) => row.record.bib.isEmpty).length;
  }

  // Helper to count duplicate bib numbers
  int countDuplicateBibNumbers() {
    return _rows
        .where((row) => row.record.flags.duplicateBibNumber == true)
        .length;
  }

  // Helper to count unknown bib numbers
  int countUnknownBibNumbers() {
    return _rows.where((row) => row.record.flags.notInDatabase == true).length;
  }

  @override
  void dispose() {
    // Remove focus listeners first so focus events firing during teardown
    // cannot call notifyListeners() on the partially-disposed controller.
    for (final row in _rows) {
      try {
        row.dispose();
      } catch (e) {
        Logger.e('Warning: Error disposing bib row: $e');
      }
    }
    _rows.clear();
    currentRaceNotifier.dispose();
    keyboardVisibleNotifier.dispose();
    super.dispose();
  }
}
