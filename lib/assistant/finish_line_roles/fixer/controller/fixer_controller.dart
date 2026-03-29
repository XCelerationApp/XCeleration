import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/services/phonetic_search.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/race_data_loader.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Controls the Fixer role.
///
/// The Fixer resolves entries that the Bib Recorder flagged as DUPLICATE /
/// UNKNOWN, or that the Verifier explicitly rejected. Resolution options:
///   • Match to an existing runner (via fuzzy name search)
///   • Correct the bib number directly
///   • Create a new runner record
class FixerController extends ChangeNotifier {
  FixerController({
    required IAssistantStorageService storage,
    IHapticFeedback? haptic,
  })  : _storage = storage,
        _haptic = haptic ?? HapticFeedbackService();

  final IAssistantStorageService _storage;
  final IHapticFeedback _haptic;
  int _raceId = 0;
  P2PSessionService? _session;

  final List<FixerEntry> _queue = [];
  final List<Runner> _allRunners = [];
  List<Runner> _searchResults = [];
  String _searchQuery = '';
  bool _inRace = false;
  StreamSubscription<(Role, MessageEnvelope)>? _sessionSub;

  List<RaceRecord> _races = [];

  List<FixerEntry> get queue => List.unmodifiable(_queue);
  List<Runner> get searchResults => List.unmodifiable(_searchResults);
  String get searchQuery => _searchQuery;

  int get unresolvedCount => _queue.where((e) => !e.isResolved).length;
  bool get isInRace => _inRace;

  /// Locally stored races loaded from storage (pre-loaded from Coach).
  List<RaceRecord> get races => List.unmodifiable(_races);

  Future<void> initialize() async {
    await _loadRaces();
  }

  /// Attaches [session] to this controller for the race identified by [raceId].
  ///
  /// Cancels any existing session subscription and disposes the old session
  /// before subscribing to [session]'s incoming messages.
  void attachSession(P2PSessionService session, {required int raceId}) {
    _sessionSub?.cancel();
    _session?.dispose();
    _session = session;
    _raceId = raceId;
    _sessionSub = session.incomingMessages.listen(_onSessionMessage);
  }

  /// Cancels the active session subscription and disposes the session.
  void detachSession() {
    _sessionSub?.cancel();
    _sessionSub = null;
    _session?.dispose();
    _session = null;
  }

  Future<void> _loadRaces() async {
    final result = await _storage.getRaces(DeviceName.fixer.toString());
    switch (result) {
      case Success(:final value):
        _races = value;
      case Failure(:final error):
        Logger.e('[FixerController._loadRaces] ${error.originalException}');
    }
    notifyListeners();
  }

  // ── Race loading ──────────────────────────────────────────────────────────

  /// Parses [data] received from the Coach and saves the race and runners to
  /// local storage.
  Future<Result<void>> processLoadedRaceData(String data) =>
      processLoadedRaceDataShared(
        data: data,
        deviceName: DeviceName.fixer,
        storage: _storage,
        onComplete: _loadRaces,
      );

  /// Enter a race session.
  Future<void> joinRace() async {
    _inRace = true;
    notifyListeners();
    final result = await _storage.getRunners(_raceId);
    switch (result) {
      case Success(:final value):
        _allRunners.addAll(value);
      case Failure(:final error):
        Logger.e('[FixerController.joinRace] ${error.originalException}');
    }
    notifyListeners();
  }

  void leaveRace() {
    _inRace = false;
    _queue.clear();
    _allRunners.clear();
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }

  Future<void> deleteRaceFromLobby(int raceId) async {
    final result = await _storage.deleteRace(raceId, DeviceName.fixer.toString());
    switch (result) {
      case Success():
        _races.removeWhere((r) => r.raceId == raceId);
        notifyListeners();
      case Failure(:final error):
        Logger.e('[FixerController.deleteRaceFromLobby] ${error.originalException}');
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Filters runners using phonetic (Soundex) + substring scoring.
  /// Returns the top 5 matches ranked by relevance.
  void search(String query) {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    final scored = <({Runner runner, double score})>[];
    for (final r in _allRunners) {
      final s = PhoneticSearch.score(query, r);
      if (s > 0) scored.add((runner: r, score: s));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    _searchResults = scored.take(5).map((e) => e.runner).toList();
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  // ── Resolution ────────────────────────────────────────────────────────────

  /// Resolve by matching to an existing runner in the roster.
  void resolveWithRunner(int entryId, Runner runner) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    unawaited(_haptic.lightImpact());
    final original = _queue[idx];
    final correctedBib = int.tryParse(runner.bibNumber) ?? original.bib;
    final resolvedName = runner.name ?? runner.bibNumber;
    _queue[idx] = original.copyWith(
      isResolved: true,
      correctedBib: correctedBib,
      resolvedName: resolvedName,
    );
    if (_session != null) {
      unawaited(_session!.sendMessage(
        Role.bibRecorderV2,
        MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
          finishPosition: original.position,
          originalBib: original.bib,
          correctedBib: correctedBib,
          correctionType: CorrectionType.matched,
        )),
      ));
    }
    notifyListeners();
  }

  /// Resolve by entering the correct bib number directly.
  void resolveWithBib(int entryId, int newBib) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    unawaited(_haptic.lightImpact());
    final original = _queue[idx];
    _queue[idx] = original.copyWith(isResolved: true, correctedBib: newBib);
    if (_session != null) {
      unawaited(_session!.sendMessage(
        Role.bibRecorderV2,
        MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
          finishPosition: original.position,
          originalBib: original.bib,
          correctedBib: newBib,
          correctionType: CorrectionType.bibCorrected,
        )),
      ));
    }
    notifyListeners();
  }

  /// Resolve by creating a new runner record (unknown runner, no roster match).
  ///
  /// When [newBib] is null, a correction is still sent to the BibRecorder to
  /// mark the entry as a new-runner resolution without changing the bib number.
  void resolveAsNewRunner(int entryId, {String? name, int? newBib}) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    unawaited(_haptic.lightImpact());
    final original = _queue[idx];
    final resolvedName = name ?? 'New Runner';
    final bibNumber = (newBib ?? entryId).toString();
    _queue[idx] = original.copyWith(
      isResolved: true,
      isNewRunner: true,
      resolvedName: resolvedName,
      correctedBib: newBib,
    );
    if (_session != null) {
      unawaited(_session!.sendMessage(
        Role.bibRecorderV2,
        MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
          finishPosition: original.position,
          originalBib: original.bib,
          correctedBib: newBib,
          correctionType: CorrectionType.newRunner,
        )),
      ));
    }
    unawaited(_storage.saveRunner(Runner(
      raceId: _raceId,
      bibNumber: bibNumber,
      name: name,
      createdAt: DateTime.now(),
    )).then((result) {
      if (result case Failure(:final error)) {
        Logger.e('[FixerController.resolveAsNewRunner] ${error.originalException}');
      }
    }));
    notifyListeners();
  }

  // ── P2P ───────────────────────────────────────────────────────────────────

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    if (envelope.type != MessageType.verifierFlag) return;
    try {
      _addEntryFromFlag(envelope.decode() as VerifierFlagMessage);
    } catch (e) {
      Logger.e('[FixerController._onSessionMessage] Malformed message dropped: $e');
    }
  }

  void _addEntryFromFlag(VerifierFlagMessage msg) {
    unawaited(_haptic.vibrate());
    final reason = switch (msg.reason) {
      FlagReason.wrongName => FixReason.verifierFlagged,
      FlagReason.unknown => FixReason.unknown,
      FlagReason.duplicate => FixReason.duplicate,
    };
    _queue.insert(
      0,
      FixerEntry(
        id: msg.entry.entryId ?? msg.entry.finishPosition,
        position: msg.entry.finishPosition,
        bib: msg.entry.bib,
        reason: reason,
      ),
    );
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sessionSub?.cancel();
    _session?.dispose();
    super.dispose();
  }

}
