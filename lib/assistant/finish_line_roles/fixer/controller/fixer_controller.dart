import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/services/phonetic_search.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_correction_message.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/i_bib_correction_channel.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
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
    required int raceId,
    P2PSessionService? session,
    IBibCorrectionChannel? correctionChannel,
  })  : _storage = storage,
        _raceId = raceId,
        _session = session,
        _correctionChannel = correctionChannel;

  final IAssistantStorageService _storage;
  final int _raceId;
  final P2PSessionService? _session;
  final IBibCorrectionChannel? _correctionChannel;

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
    if (_session != null) {
      _sessionSub = _session.incomingMessages.listen(_onSessionMessage);
    }
    await _loadRaces();
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
  /// local storage. Returns [Failure] with a user-readable message if parsing
  /// or saving fails.
  Future<Result<void>> processLoadedRaceData(String data) async {
    late RaceRecord raceRecord;
    List<BibDatum> loadedRunners = [];

    try {
      final parts = data.split('---');
      if (parts.length == 2) {
        raceRecord = RaceRecord.fromEncodedString(parts[0],
            type: DeviceName.fixer.toString());

        final runnersResult =
            await BibDecodeUtils.decodeEncodedRunners(parts[1]);
        switch (runnersResult) {
          case Success(:final value):
            loadedRunners = value;
          case Failure(:final error):
            Logger.e(
                '[FixerController.processLoadedRaceData] ${error.originalException}');
            return Failure(error);
        }
      } else {
        raceRecord = RaceRecord.fromEncodedString(data,
            type: DeviceName.fixer.toString());
      }
    } catch (e) {
      Logger.e('Error parsing race data: $e');
      return Failure(AppError(userMessage: 'Failed to parse race data: $e'));
    }

    final saveResult = await _storage.saveNewRace(raceRecord);
    if (saveResult case Failure(:final error)) {
      Logger.e(
          '[FixerController.processLoadedRaceData] ${error.originalException}');
      await _loadRaces();
      return Failure(error);
    }

    if (loadedRunners.isNotEmpty) {
      final dbRunners = loadedRunners
          .map((runner) => Runner(
                raceId: raceRecord.raceId,
                bibNumber: runner.bib,
                name: runner.name,
                teamAbbreviation: runner.teamAbbreviation,
                grade: runner.grade,
                teamColor: runner.teamColor,
                createdAt: DateTime.now(),
              ))
          .toList();
      await _storage.saveRunners(raceRecord.raceId, dbRunners);
    }

    await _loadRaces();
    return const Success(null);
  }

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
    final original = _queue[idx];
    final correctedBib = int.tryParse(runner.bibNumber) ?? original.bib;
    final resolvedName = runner.name ?? runner.bibNumber;
    _queue[idx] = original.copyWith(
      isResolved: true,
      correctedBib: correctedBib,
      resolvedName: resolvedName,
    );
    _correctionChannel?.sendCorrection(BibCorrectionMessage(
      entryId: original.position,
      originalBib: original.bib,
      correctedBib: correctedBib,
      resolvedName: resolvedName,
    ));
    if (_session != null) {
      unawaited(_session.sendMessage(
        Role.bibRecorderV2,
        MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
          finishPosition: original.position,
          originalBib: original.bib,
          correctedBib: correctedBib,
          correctionType: CorrectionType.matched,
        )),
      ));
    }
    unawaited(_storage.updateBibRecordValue(_raceId, entryId, correctedBib.toString()).then((result) {
      if (result case Failure(:final error)) {
        Logger.e('[FixerController.resolveWithRunner] ${error.originalException}');
      }
    }));
    notifyListeners();
  }

  /// Resolve by entering the correct bib number directly.
  void resolveWithBib(int entryId, int newBib) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    final original = _queue[idx];
    _queue[idx] = original.copyWith(isResolved: true, correctedBib: newBib);
    _correctionChannel?.sendCorrection(BibCorrectionMessage(
      entryId: original.position,
      originalBib: original.bib,
      correctedBib: newBib,
    ));
    if (_session != null) {
      unawaited(_session.sendMessage(
        Role.bibRecorderV2,
        MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
          finishPosition: original.position,
          originalBib: original.bib,
          correctedBib: newBib,
          correctionType: CorrectionType.bibCorrected,
        )),
      ));
    }
    unawaited(_storage.updateBibRecordValue(_raceId, entryId, newBib.toString()).then((result) {
      if (result case Failure(:final error)) {
        Logger.e('[FixerController.resolveWithBib] ${error.originalException}');
      }
    }));
    notifyListeners();
  }

  /// Resolve by creating a new runner record (unknown runner, no roster match).
  void resolveAsNewRunner(int entryId, {String? name, int? newBib}) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    final original = _queue[idx];
    final resolvedName = name ?? 'New Runner';
    final bibNumber = (newBib ?? entryId).toString();
    _queue[idx] = original.copyWith(
      isResolved: true,
      isNewRunner: true,
      resolvedName: resolvedName,
      correctedBib: newBib,
    );
    _correctionChannel?.sendCorrection(BibCorrectionMessage(
      entryId: original.position,
      originalBib: original.bib,
      correctedBib: newBib,
      resolvedName: resolvedName,
      isNewRunner: true,
    ));
    if (_session != null) {
      unawaited(_session.sendMessage(
        Role.bibRecorderV2,
        MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage(
          finishPosition: original.position,
          originalBib: original.bib,
          correctedBib: newBib ?? original.bib,
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
    if (newBib != null) {
      unawaited(_storage.updateBibRecordValue(_raceId, entryId, newBib.toString()).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[FixerController.resolveAsNewRunner] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  // ── P2P ───────────────────────────────────────────────────────────────────

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    if (envelope.type != MessageType.verifierFlag) return;
    _addEntryFromFlag(envelope.decode() as VerifierFlagMessage);
  }

  void _addEntryFromFlag(VerifierFlagMessage msg) {
    final reason = switch (msg.reason) {
      FlagReason.wrongName => FixReason.verifierFlagged,
      FlagReason.unknown => FixReason.unknown,
      FlagReason.duplicate => FixReason.duplicate,
    };
    _queue.insert(
      0,
      FixerEntry(
        id: msg.entry.finishPosition,
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
    super.dispose();
  }

}
