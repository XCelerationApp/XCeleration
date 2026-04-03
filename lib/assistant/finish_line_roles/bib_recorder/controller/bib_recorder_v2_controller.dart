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
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
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
    _raceStarted = !race.stopped;
    _raceStopped = race.stopped;
    _entries.clear();
    _runners.clear();
    _loadRunners();
    _loadBibRecords();
    notifyListeners();
  }

  void beginRace() {
    _raceStarted = true;
    _raceStopped = false;
    notifyListeners();
  }

  void stopRace() {
    _raceStopped = true;
    notifyListeners();
    unawaited(_handOffUnresolvedEntries());
  }

  void resumeRace() {
    _raceStarted = true;
    _raceStopped = false;
    notifyListeners();
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
    if (_selectedRace == null) return;
    final result = await _storage.getRunners(_selectedRace!.raceId);
    switch (result) {
      case Success(:final value):
        _runners
          ..clear()
          ..addAll(value);
        notifyListeners();
      case Failure(:final error):
        Logger.e('[BibRecorderV2Controller._loadRunners] ${error.originalException}');
    }
  }

  Future<void> _loadBibRecords() async {
    if (_selectedRace == null) return;
    final result = await _storage.getBibRecords(_selectedRace!.raceId);
    switch (result) {
      case Success(:final value):
        _entries.clear();
        _positionToEntryId.clear();
        _nextPosition = 0;
        _nextEntryId = 0;
        for (final BibRecord record in value) {
          final bib = int.tryParse(record.bibNumber);
          if (bib != null) {
            _entries.add(BibEntry(id: record.bibId, bib: bib));
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
    final entry = BibEntry(id: _nextEntryId++, bib: bib);
    _entries.insert(0, entry);
    if (flagFor(bib, excludeId: entry.id) != null) _haptic.vibrate();
    _nextPosition++;
    _positionToEntryId[_nextPosition] = entry.id;
    _sendBibEntry(entry.id, bib, _nextPosition);
    _persistAddBib(entry.id, bib);
    notifyListeners();
  }

  // ── Bib entry management ──────────────────────────────────────────────────

  /// Adds a bib entry directly (used by manual mode).
  void addBib(int bib) {
    _awaitingRecord = false;
    final entry = BibEntry(id: _nextEntryId++, bib: bib);
    _entries.insert(0, entry);
    _nextPosition++;
    _positionToEntryId[_nextPosition] = entry.id;
    _sendBibEntry(entry.id, bib, _nextPosition);
    _persistAddBib(entry.id, bib);
    notifyListeners();
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
    _positionToEntryId.removeWhere((_, entryId) => entryId == id);
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
    _entries[idx] = _entries[idx].copyWith(bib: newBib);
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

  Future<void> _handOffUnresolvedEntries() async {
    if (_selectedRace == null) return;
    final raceId = _selectedRace!.raceId;
    final unresolved = _entries
        .where((e) => e.correctedTo == null && flagFor(e.bib, excludeId: e.id) != null)
        .toList();
    for (final entry in unresolved) {
      final conflict = TimingDatum(
        time: '',
        conflict: Conflict(type: ConflictType.confirmRunner),
      );
      final saveResult = await _storage.saveChunk(
        raceId,
        TimingChunk(id: entry.id, timingData: const [], conflictRecord: conflict),
      );
      if (saveResult case Failure(:final error)) {
        Logger.e('[BibRecorderV2Controller._handOffUnresolvedEntries] ${error.originalException}');
        continue;
      }
      final conflictResult = await _storage.saveChunkConflict(raceId, entry.id, conflict);
      if (conflictResult case Failure(:final error)) {
        Logger.e('[BibRecorderV2Controller._handOffUnresolvedEntries] ${error.originalException}');
      }
    }
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
    final bibData = _entries.map((entry) {
      final runner = runnerFor(entry.bib);
      return BibDatum(
        bib: entry.bib.toString(),
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

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    if (envelope.type != MessageType.fixerCorrection) return;
    try {
      _applyCorrection(envelope.decode() as FixerCorrectionMessage);
    } catch (e) {
      Logger.e('[BibRecorderV2Controller._onSessionMessage] Malformed message dropped: $e');
    }
  }

  void _applyCorrection(FixerCorrectionMessage msg) {
    final entryId = _positionToEntryId[msg.finishPosition];
    if (entryId == null) return;
    final idx = _entries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
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
    } else if (msg.correctionType == CorrectionType.newRunner) {
      _entries[idx] = _entries[idx].copyWith(isNewRunner: true);
    }
    notifyListeners();
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
