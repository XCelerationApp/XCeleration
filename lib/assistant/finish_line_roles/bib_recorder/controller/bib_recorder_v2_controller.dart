import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/voice_recognition_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
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
  final P2PSessionService? _session;

  StreamSubscription<int?>? _bibSub;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<(Role, MessageEnvelope)>? _sessionSub;

  // Monotonically increasing finish position — incremented on every bib insert.
  int _nextPosition = 0;
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

  /// Call once after creating the controller. Loads races and initialises the
  /// voice service in parallel. If a [P2PSessionService] was provided it also
  /// subscribes to incoming [FixerCorrectionMessage]s.
  Future<void> initialize() async {
    if (_session != null) {
      _sessionSub = _session.incomingMessages.listen(_onSessionMessage);
    }
    await Future.wait([
      _loadRaces(),
      _initVoice(),
    ]);
  }

  Future<void> _loadRaces() async {
    final result = await _storage.getRaces(DeviceName.bibRecorder.toString());
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
  }

  void resumeRace() {
    _raceStopped = false;
    notifyListeners();
  }

  void leaveRace() {
    _selectedRace = null;
    _raceStarted = false;
    _raceStopped = false;
    _entries.clear();
    _runners.clear();
    _transcript = '';
    _isListening = false;
    _isProcessing = false;
    _awaitingRecord = false;
    notifyListeners();
  }

  void deleteRace() {
    leaveRace();
    // TODO: persist deletion via storage when bib entries are persisted
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

  // ── Flag helpers ──────────────────────────────────────────────────────────

  /// Returns `'duplicate'`, `'unknown'`, or `null` for a given bib.
  /// Pass [excludeId] to skip the entry being edited/checked.
  String? flagFor(int bib, {int? excludeId}) {
    final isDuplicate =
        _entries.any((e) => e.bib == bib && e.id != excludeId);
    if (isDuplicate) return 'duplicate';
    final inRoster =
        _runners.any((r) => r.bibNumber == bib.toString());
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

  void _onBibRecognized(int? bib) {
    _isProcessing = false;
    _transcript = '';
    _awaitingRecord = false;
    if (bib != null) {
      final entry = BibEntry(id: DateTime.now().millisecondsSinceEpoch, bib: bib);
      _entries.insert(0, entry);
      if (flagFor(bib) != null) _haptic.vibrate();
      _nextPosition++;
      _positionToEntryId[_nextPosition] = entry.id;
      _sendBibEntry(entry.id, bib, _nextPosition);
    }
    notifyListeners();
  }

  // ── Bib entry management ──────────────────────────────────────────────────

  /// Adds a bib entry directly (used by manual mode).
  void addBib(int bib) {
    _awaitingRecord = false;
    final entry = BibEntry(id: DateTime.now().millisecondsSinceEpoch, bib: bib);
    _entries.insert(0, entry);
    if (flagFor(bib) != null) _haptic.vibrate();
    _nextPosition++;
    _positionToEntryId[_nextPosition] = entry.id;
    _sendBibEntry(entry.id, bib, _nextPosition);
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
    notifyListeners();
  }

  void editEntry(int id, int newBib) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(bib: newBib);
    notifyListeners();
  }

  void clearEntries() {
    _entries.clear();
    _awaitingRecord = false;
    notifyListeners();
  }

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

  void _sendBibEntry(int entryId, int bib, int position) {
    if (_session == null) return;
    final flag = flagFor(bib, excludeId: entryId);
    final status = flag == 'duplicate'
        ? BibEntryStatus.duplicate
        : flag == 'unknown'
            ? BibEntryStatus.unknown
            : BibEntryStatus.resolved;
    unawaited(_session.sendMessage(
      Role.verifier,
      MessageEnvelope.wrapBibEntry(BibEntryMessage(
        finishPosition: position,
        bib: bib,
        status: status,
        timestamp: DateTime.now(),
      )),
    ));
  }

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    if (envelope.type != MessageType.fixerCorrection) return;
    _applyCorrection(envelope.decode() as FixerCorrectionMessage);
  }

  void _applyCorrection(FixerCorrectionMessage msg) {
    final entryId = _positionToEntryId[msg.finishPosition];
    if (entryId == null) return;
    final idx = _entries.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(correctedTo: msg.correctedBib);
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _bibSub?.cancel();
    _transcriptSub?.cancel();
    _sessionSub?.cancel();
    _voice.dispose();
    super.dispose();
  }
}
