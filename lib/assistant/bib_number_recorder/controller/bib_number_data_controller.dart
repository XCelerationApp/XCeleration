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

  bool _isKeyboardVisible = false;

  // Race context and storage - single source of truth
  final IAssistantStorageService storage;
  final ITextInputFactory _textInputFactory;
  RaceRecord? _currentRace;
  bool _raceStopped = true;

  BibNumberDataController({
    required this.storage,
    required ITextInputFactory textInputFactory,
  }) : _textInputFactory = textInputFactory;

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
    final controller = _textInputFactory.createController(record.bib);
    controllers.add(controller);

    final focusNode = _textInputFactory.createFocusNode();
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
