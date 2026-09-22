import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/voice_recognition_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/bib_record.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/race_data_loader.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Controls the full lifecycle of the new Bib Recorder role:
///   Lobby → Race Mode (live recording) → Manage Mode (post-race review).
///
/// Voice recognition is owned and managed here. Widgets are purely
/// presentational — they call controller methods and read controller state.
class BibRecorderV2Controller extends ChangeNotifier {
  BibRecorderV2Controller({
    required IAssistantStorageService storage,
    IVoiceRecognitionService? voice,
    IHapticFeedback? haptic,
    P2PSessionService? session,
  })  : _storage = storage,
        _voice = voice ?? VoiceRecognitionService.create(),
        _haptic = haptic ?? HapticFeedbackService(),
        _session = session;

  final IAssistantStorageService _storage;
  final IVoiceRecognitionService _voice;
  final IHapticFeedback _haptic;
  P2PSessionService? _session;

  /// When set, voice-recognized bibs are delivered here instead of being added
  /// directly to entries. The widget can display the bib in an editable field
  /// and start an auto-submit timer before calling [addBib].
  ValueChanged<String>? onBibPending;

  StreamSubscription<String?>? _bibSub;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<(Role, MessageEnvelope)>? _sessionSub;

  // Monotonically increasing finish position — incremented on every bib insert.
  int _nextPosition = 0;
  // Monotonically increasing entry ID — avoids collisions from rapid adds.
  int _nextEntryId = 0;
  // Maps finish position → BibEntry.id for applying Fixer corrections.
  final Map<int, int> _positionToEntryId = {};

  // While a selected race's saved bibs are loading, new bibs and Fixer
  // corrections are held here and applied once the load finishes. Applying
  // them earlier would lose them when the load replaces the list, and new
  // entry ids would restart at 0 and overwrite saved rows.
  bool _loadingRecords = false;
  final List<({int bib, bool fromVoice})> _bibsWhileLoading = [];
  final List<FixerCorrectionMessage> _correctionsWhileLoading = [];

  // ── Race-selection state ──────────────────────────────────────────────────

  List<RaceRecord> _races = [];
  RaceRecord? _selectedRace;
  bool _raceStarted = false;
  bool _raceStopped = false;

  List<RaceRecord> get races => List.unmodifiable(_races);
  RaceRecord? get selectedRace => _selectedRace;
  bool get raceStarted => _raceStarted;
  bool get raceStopped => _raceStopped;

  // ── Bib-entry state ───────────────────────────────────────────────────────

  final List<BibEntry> _entries = [];
  final List<Runner> _runners = [];

  List<BibEntry> get entries => List.unmodifiable(_entries);
  List<Runner> get runners => List.unmodifiable(_runners);

  // ── Voice state ───────────────────────────────────────────────────────────

  bool _voiceReady = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcript = '';
  // True immediately after reRecordLast() until the next bib is added.
  // While true, lastAddedBib returns null so the card shows idle.
  bool _awaitingRecord = false;
  AppError? _voiceError;

  bool get voiceReady => _voiceReady;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  String get transcript => _transcript;
  AppError? get voiceError => _voiceError;

  /// The most recently added bib, or null if no entries or re-record was just
  /// tapped (card should show idle until the next bib arrives).
  int? get lastAddedBib =>
      _awaitingRecord || _entries.isEmpty ? null : _entries.first.bib;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once after creating the controller. Loads races and starts voice
  /// initialisation in the background (does not block on it). If a
  /// [P2PSessionService] was provided it also subscribes to incoming
  /// [FixerCorrectionMessage]s.
  Future<void> initialize() async {
    if (_session != null) {
      _sessionSub = _session!.incomingMessages.listen(_onSessionMessage);
    }
    // Fire-and-forget: voice loads in the background so the lobby appears
    // immediately. The mic is gated on _voiceReady in RaceModeWidget.
    unawaited(_initVoice());
    await _loadRaces();
  }

  Future<void> _loadRaces() async {
    final result = await _storage.getRaces(DeviceName.bibRecorderV2.toString());
    switch (result) {
      case Success(:final value):
        _races = value;
      case Failure(:final error):
        Logger.e('[BibRecorderV2Controller._loadRaces] ${error.originalException}');
    }
    notifyListeners();
  }

  Future<void> _initVoice() async {
    _bibSub = _voice.bibNumbers.listen(_onBibRecognized);
    _transcriptSub = _voice.partialResults.listen(_onTranscript);

    final result = await _voice.initialize();
    switch (result) {
      case Success():
        _voiceReady = true;
      case Failure(:final error):
        _voiceError = error;
        Logger.e('[BibRecorderV2Controller._initVoice] ${error.originalException}');
    }
    notifyListeners();
  }

  // ── Race navigation ───────────────────────────────────────────────────────

  void selectRace(RaceRecord race) {
    _selectedRace = race;
    // A race fresh from the Coach has no start time and opens ready to start;
    // only a race this device started and then stopped opens as finished.
    _raceStarted = race.startedAt != null && !race.stopped;
    _raceStopped = race.isFinished;
    _entries.clear();
    _runners.clear();
    _bibsWhileLoading.clear();
    _correctionsWhileLoading.clear();
    _loadingRecords = true;
    _loadRunners();
    _loadBibRecords();
    notifyListeners();
  }

  void beginRace() {
    _raceStarted = true;
    _raceStopped = false;
    _saveRaceState(stopped: false, startedAt: DateTime.now());
    notifyListeners();
  }

  void stopRace() {
    _raceStopped = true;
    _saveRaceState(stopped: true);
    notifyListeners();
  }

  void resumeRace() {
    _raceStarted = true;
    _raceStopped = false;
    _saveRaceState(stopped: false);
    notifyListeners();
  }

  /// Records the race's start time and running state, in memory and in
  /// storage, so the lobby and a reopened race show the right state.
  void _saveRaceState({required bool stopped, DateTime? startedAt}) {
    final race = _selectedRace;
    if (race == null) return;
    final updated = RaceRecord(
      raceId: race.raceId,
      date: race.date,
      name: race.name,
      type: race.type,
      stopped: stopped,
      startedAt: race.startedAt ?? startedAt,
      duration: race.duration,
    );
    _selectedRace = updated;
    _races = [
      for (final r in _races) r.raceId == race.raceId ? updated : r,
    ];
    void logFailure(Result<void> result) {
      if (result case Failure(:final error)) {
        Logger.e('[BibRecorderV2Controller._saveRaceState] ${error.originalException}');
      }
    }

    if (race.startedAt == null && startedAt != null) {
      unawaited(_storage
          .updateRaceStartTime(race.raceId, race.type, startedAt)
          .then(logFailure));
    }
    unawaited(
        _storage.updateRaceStatus(race.raceId, race.type, stopped).then(logFailure));
  }

  void leaveRace() {
    _selectedRace = null;
    _raceStarted = false;
    _raceStopped = false;
    _entries.clear();
    _runners.clear();
    _nextPosition = 0;
    _nextEntryId = 0;
    _positionToEntryId.clear();
    _loadingRecords = false;
    _bibsWhileLoading.clear();
    _correctionsWhileLoading.clear();
    _transcript = '';
    _isListening = false;
    _isProcessing = false;
    _awaitingRecord = false;
    notifyListeners();
  }

  Future<void> deleteRace() async {
    final raceId = _selectedRace?.raceId;
    leaveRace();
    if (raceId != null) {
      final result = await _storage.deleteRace(raceId, DeviceName.bibRecorderV2.toString());
      if (result case Failure(:final error)) {
        Logger.e('[BibRecorderV2Controller.deleteRace] ${error.originalException}');
      }
    }
  }

  Future<void> deleteRaceFromLobby(int raceId) async {
    final result = await _storage.deleteRace(raceId, DeviceName.bibRecorderV2.toString());
    switch (result) {
      case Success():
        _races.removeWhere((r) => r.raceId == raceId);
        notifyListeners();
      case Failure(:final error):
        Logger.e('[BibRecorderV2Controller.deleteRaceFromLobby] ${error.originalException}');
    }
  }

  // ── Runners ───────────────────────────────────────────────────────────────

  Future<void> _loadRunners() async {
    final race = _selectedRace;
    if (race == null) return;
    final result = await _storage.getRunners(race.raceId);
    if (!identical(_selectedRace, race)) return; // another race was selected
    switch (result) {
      case Success(:final value):
        // Keep runners added while loading (e.g. a Fixer's new runner).
        final loadedBibs = value.map((r) => r.bibNumber).toSet();
        final addedMeanwhile =
            _runners.where((r) => !loadedBibs.contains(r.bibNumber)).toList();
        _runners
          ..clear()
          ..addAll(value)
          ..addAll(addedMeanwhile);
        notifyListeners();
      case Failure(:final error):
        Logger.e('[BibRecorderV2Controller._loadRunners] ${error.originalException}');
    }
  }

  Future<void> _loadBibRecords() async {
    final race = _selectedRace;
    if (race == null) return;
    final result = await _storage.getBibRecords(race.raceId);
    if (!identical(_selectedRace, race)) return; // another race was selected
    switch (result) {
      case Success(:final value):
        _entries.clear();
        _positionToEntryId.clear();
        _nextPosition = 0;
        _nextEntryId = 0;
        for (final BibRecord record in value) {
          final bib = int.tryParse(record.bibNumber);
          if (bib != null) {
            // Records come back oldest-first; the list is kept newest-first.
            _entries.insert(0, BibEntry(id: record.bibId, bib: bib));
            _nextPosition++;
            _positionToEntryId[_nextPosition] = record.bibId;
            if (record.bibId >= _nextEntryId) {
              _nextEntryId = record.bibId + 1;
            }
          }
        }
        notifyListeners();
      case Failure(:final error):
        _positionToEntryId.clear();
        _nextPosition = 0;
        _nextEntryId = 0;
        Logger.e('[BibRecorderV2Controller._loadBibRecords] ${error.originalException}');
    }
    _applyHeldWhileLoading();
  }

  /// Applies bibs and corrections that arrived while the race was loading,
  /// in the order they arrived.
  void _applyHeldWhileLoading() {
    _loadingRecords = false;
    final bibs = List.of(_bibsWhileLoading);
    final corrections = List.of(_correctionsWhileLoading);
    _bibsWhileLoading.clear();
    _correctionsWhileLoading.clear();
    for (final held in bibs) {
      _insertEntry(held.bib, vibrateIfFlagged: held.fromVoice);
    }
    for (final correction in corrections) {
      _applyCorrection(correction);
    }
    if (bibs.isNotEmpty || corrections.isNotEmpty) notifyListeners();
  }

  // ── Flag helpers ──────────────────────────────────────────────────────────

  /// Returns `'duplicate'`, `'unknown'`, or `null` for a given bib.
  /// Pass [excludeId] to skip the entry being edited/checked.
  ///
  /// Corrected entries (where [BibEntry.correctedTo] is non-null) and new-runner
  /// entries (where [BibEntry.isNewRunner] is true) are excluded from duplicate
  /// checks — their original bib is no longer the active value.
  String? flagFor(int bib, {int? excludeId}) {
    // If the specific entry being checked is a new runner, it's already resolved.
    if (excludeId != null && _entries.any((e) => e.id == excludeId && e.isNewRunner)) {
      return null;
    }
    final isDuplicate = _entries.any(
      (e) => e.bib == bib && e.id != excludeId && e.correctedTo == null && !e.isNewRunner,
    );
    if (isDuplicate) return 'duplicate';
    final inRoster = _runners.any((r) => r.bibNumber == bib.toString());
    if (_runners.isNotEmpty && !inRoster) return 'unknown';
    return null;
  }

  /// Entries still flagged as duplicate or not in the roster, excluding those
  /// the Fixer has corrected.
  int get unresolvedCount => _entries
      .where((e) => e.correctedTo == null && flagFor(e.bib, excludeId: e.id) != null)
      .length;

  Runner? runnerFor(int bib) =>
      _runners.where((r) => r.bibNumber == bib.toString()).firstOrNull;

  // ── Voice recording ───────────────────────────────────────────────────────

  /// Called when the user presses the mic button.
  Future<void> startListening() async {
    if (!_voiceReady || _isListening) return;
    _isListening = true;
    _transcript = '';
    notifyListeners();
    await _voice.start();
  }

  /// Called when the user releases the mic button.
  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    _isProcessing = true;
    notifyListeners();
    await _voice.stop();
    // Streams will fire _onTranscript and _onBibRecognized.
  }

  void _onTranscript(String transcript) {
    _transcript = transcript;
    notifyListeners();
  }

  void _onBibRecognized(String? bibStr) {
    _isProcessing = false;
    _transcript = '';
    _awaitingRecord = false;
    if (bibStr == null) {
      _haptic.vibrate();
      notifyListeners();
      return;
    }
    final bib = int.tryParse(bibStr);
    if (bib == null) return;
    if (onBibPending != null) {
      if (flagFor(bib) != null) _haptic.vibrate();
      notifyListeners();
      onBibPending!(bibStr);
      return;
    }
    if (_loadingRecords) {
      _bibsWhileLoading.add((bib: bib, fromVoice: true));
    } else {
      _insertEntry(bib, vibrateIfFlagged: true);
    }
    notifyListeners();
  }

  // ── Bib entry management ──────────────────────────────────────────────────

  /// Adds a bib entry directly (used by manual mode).
  void addBib(int bib) {
    _awaitingRecord = false;
    if (_loadingRecords) {
      _bibsWhileLoading.add((bib: bib, fromVoice: false));
    } else {
      _insertEntry(bib, vibrateIfFlagged: false);
    }
    notifyListeners();
  }

  /// Records [bib] as the next finisher: list, storage and Verifier.
  void _insertEntry(int bib, {required bool vibrateIfFlagged}) {
    final entry = BibEntry(id: _nextEntryId++, bib: bib);
    _entries.insert(0, entry);
    if (vibrateIfFlagged && flagFor(bib, excludeId: entry.id) != null) {
      _haptic.vibrate();
    }
    _nextPosition++;
    _positionToEntryId[_nextPosition] = entry.id;
    _sendBibEntry(entry.id, bib, _nextPosition);
    _persistAddBib(entry.id, bib);
  }

  /// Signals the card to show idle until the next bib is recorded.
  /// The most recently added entry remains in the list below.
  void reRecordLast() {
    if (_entries.isEmpty) return;
    _awaitingRecord = true;
    notifyListeners();
  }

  void deleteEntry(int id) {
    _entries.removeWhere((e) => e.id == id);
    // The position mapping is kept so an undo can restore the same position;
    // corrections for a deleted entry are dropped because it is not in
    // [_entries].
    _sendBibEntryDeleted(id);
    if (_selectedRace != null) {
      unawaited(_storage.removeBibRecord(_selectedRace!.raceId, id).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[BibRecorderV2Controller.deleteEntry] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  void editEntry(int id, int newBib) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    // A manual edit replaces any earlier Fixer correction.
    _entries[idx] = _entries[idx].copyWith(bib: newBib, correctedTo: () => null);
    final position = _positionOf(id);
    if (position != null) _sendBibEntry(id, newBib, position);
    if (_selectedRace != null) {
      unawaited(_storage.updateBibRecordValue(_selectedRace!.raceId, id, newBib.toString()).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[BibRecorderV2Controller.editEntry] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  void restoreEntry(BibEntry entry, int index) {
    _entries.insert(index.clamp(0, _entries.length), entry);
    final position = _positionOf(entry.id);
    if (position != null) {
      _sendBibEntry(entry.id, entry.correctedTo ?? entry.bib, position);
    }
    if (_selectedRace != null) {
      unawaited(_storage.addBibRecord(_selectedRace!.raceId, entry.id, entry.bib.toString()).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[BibRecorderV2Controller.restoreEntry] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  void clearEntries() {
    for (final entry in _entries) {
      _sendBibEntryDeleted(entry.id);
    }
    _entries.clear();
    _awaitingRecord = false;
    if (_selectedRace != null) {
      unawaited(_storage.deleteBibRecords(_selectedRace!.raceId).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[BibRecorderV2Controller.clearEntries] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  // ── Storage persistence ───────────────────────────────────────────────────

  void _persistAddBib(int bibId, int bib) {
    if (_selectedRace == null) return;
    unawaited(_storage.addBibRecord(_selectedRace!.raceId, bibId, bib.toString()).then((result) {
      if (result case Failure(:final error)) {
        Logger.e('[BibRecorderV2Controller._persistAddBib] ${error.originalException}');
      }
    }));
  }

  // ── Race loading ──────────────────────────────────────────────────────────

  /// Parses [data] received from the Coach, saves the race and runners to
  /// storage, then reloads the race list.
  Future<Result<void>> processLoadedRaceData(String data) =>
      processLoadedRaceDataShared(
        data: data,
        deviceName: DeviceName.bibRecorderV2,
        storage: _storage,
        onComplete: _loadRaces,
      );

  // ── Share ─────────────────────────────────────────────────────────────────

  /// Encodes the current entries as bib data for sharing via [DeviceConnectionWidget].
  Future<String> getEncodedBibData() {
    // The coach pairs the i-th bib with the i-th finish time, so share in
    // finish order (oldest first) with any Fixer correction applied.
    final bibData = _entries.reversed.map((entry) {
      final bib = entry.correctedTo ?? entry.bib;
      final runner = runnerFor(bib);
      return BibDatum(
        bib: bib.toString(),
        name: runner?.name,
        teamAbbreviation: runner?.teamAbbreviation,
        grade: runner?.grade,
        teamColor: runner?.teamColor,
      );
    }).toList();
    return BibEncodeUtils.getEncodedBibData(bibData);
  }

  // ── P2P ───────────────────────────────────────────────────────────────────

  /// Attaches [session] to this controller for the current race.
  ///
  /// Safe to call after [initialize]. Cancels any existing session subscription
  /// before subscribing to [session]'s incoming messages.
  void attachSession(P2PSessionService session) {
    _sessionSub?.cancel();
    if (_session != null && _session != session) _session!.dispose();
    _session = session;
    _sessionSub = session.incomingMessages.listen(_onSessionMessage);
  }

  void _sendBibEntry(int entryId, int bib, int position) {
    if (_session == null) return;
    final flag = flagFor(bib, excludeId: entryId);
    final status = flag == 'duplicate'
        ? BibEntryStatus.duplicate
        : flag == 'unknown'
            ? BibEntryStatus.unknown
            : BibEntryStatus.resolved;
    final runner = runnerFor(bib);
    unawaited(_session!.sendMessage(
      Role.verifier,
      MessageEnvelope.wrapBibEntry(BibEntryMessage(
        finishPosition: position,
        bib: bib,
        status: status,
        timestamp: DateTime.now(),
        entryId: entryId,
        runnerName: runner?.name,
        teamAbbreviation: runner?.teamAbbreviation,
        teamColor: runner?.teamColor?.toARGB32(),
      )),
    ));
  }

  int? _positionOf(int entryId) => _positionToEntryId.entries
      .where((e) => e.value == entryId)
      .firstOrNull
      ?.key;

  /// Tells the Verifier and Fixer that an entry was deleted, so neither keeps
  /// acting on a bib the Bib Recorder no longer has.
  void _sendBibEntryDeleted(int entryId) {
    if (_session == null) return;
    final message = MessageEnvelope.wrapBibEntryDeleted(
      BibEntryDeletedMessage(entryId: entryId),
    );
    unawaited(_session!.sendMessage(Role.verifier, message));
    unawaited(_session!.sendMessage(Role.fixer, message));
  }

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    if (envelope.type != MessageType.fixerCorrection) return;
    try {
      final correction = envelope.decode() as FixerCorrectionMessage;
      if (_loadingRecords) {
        _correctionsWhileLoading.add(correction);
        return;
      }
      _applyCorrection(correction);
    } catch (e) {
      Logger.e('[BibRecorderV2Controller._onSessionMessage] Malformed message dropped: $e');
    }
  }

  void _applyCorrection(FixerCorrectionMessage msg) {
    // Match on the entry ID first: positions shift when entries are deleted
    // and are renumbered on reload, so they can point at the wrong runner.
    final byId = msg.entryId == null
        ? -1
        : _entries.indexWhere((e) => e.id == msg.entryId);
    final positionEntryId = _positionToEntryId[msg.finishPosition];
    final idx = byId != -1
        ? byId
        : msg.entryId == null && positionEntryId != null
            ? _entries.indexWhere((e) => e.id == positionEntryId)
            : -1;
    if (idx == -1) return;
    final entryId = _entries[idx].id;
    if (msg.correctedBib != null) {
      _entries[idx] = _entries[idx].copyWith(correctedTo: () => msg.correctedBib);
      if (_selectedRace != null) {
        unawaited(_storage.updateBibRecordValue(
          _selectedRace!.raceId, entryId, msg.correctedBib.toString(),
        ).then((result) {
          if (result case Failure(:final error)) {
            Logger.e('[BibRecorderV2Controller._applyCorrection] ${error.originalException}');
          }
        }));
      }
    }
    if (msg.correctionType == CorrectionType.newRunner) {
      _entries[idx] = _entries[idx].copyWith(isNewRunner: true);
      _addNewRunner(msg.correctedBib ?? _entries[idx].bib, msg.runnerName);
    }
    notifyListeners();
  }

  /// Adds a runner the Fixer identified as new to this device's roster, so the
  /// entry stops being flagged (also after a restart) and the name is shared
  /// with the coach.
  void _addNewRunner(int bib, String? name) {
    final race = _selectedRace;
    if (race == null || runnerFor(bib) != null) return;
    final runner = Runner(
      raceId: race.raceId,
      bibNumber: bib.toString(),
      name: name,
      createdAt: DateTime.now(),
    );
    _runners.add(runner);
    unawaited(_storage.saveRunner(runner).then((result) {
      if (result case Failure(:final error)) {
        Logger.e('[BibRecorderV2Controller._addNewRunner] ${error.originalException}');
      }
    }));
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _bibSub?.cancel();
    _transcriptSub?.cancel();
    _sessionSub?.cancel();
    _session?.dispose();
    _voice.dispose();
    super.dispose();
  }
}
