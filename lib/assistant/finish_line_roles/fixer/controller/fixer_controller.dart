import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/services/phonetic_search.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Controls the Fixer role.
///
/// The Fixer resolves entries that the Bib Recorder flagged as DUPLICATE /
/// UNKNOWN, or that the Verifier explicitly rejected. Resolution options:
///   • Match to an existing runner (via fuzzy name search)
///   • Correct the bib number directly
///   • Create a new runner record
class FixerController extends ChangeNotifier {
  FixerController({P2PSessionService? session}) : _session = session;

  final P2PSessionService? _session;

  final List<FixerEntry> _queue = [];
  final List<Runner> _allRunners = [];
  List<Runner> _searchResults = [];
  String _searchQuery = '';
  bool _inRace = false;
  StreamSubscription<(Role, MessageEnvelope)>? _sessionSub;

  List<FixerEntry> get queue => List.unmodifiable(_queue);
  List<Runner> get searchResults => List.unmodifiable(_searchResults);
  String get searchQuery => _searchQuery;

  int get unresolvedCount => _queue.where((e) => !e.isResolved).length;
  bool get isInRace => _inRace;

  void initialize() {
    if (_session != null) {
      _sessionSub = _session.incomingMessages.listen(_onSessionMessage);
    }
  }

  /// Enter a race session.
  void joinRace() {
    _inRace = true;
    _allRunners.addAll(_stubRunners());
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
    _queue[idx] = original.copyWith(
      isResolved: true,
      correctedBib: correctedBib,
      resolvedName: runner.name ?? runner.bibNumber,
    );
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
    notifyListeners();
  }

  /// Resolve by entering the correct bib number directly.
  void resolveWithBib(int entryId, int newBib) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    final original = _queue[idx];
    _queue[idx] = original.copyWith(isResolved: true, correctedBib: newBib);
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
    notifyListeners();
  }

  /// Resolve by creating a new runner record (unknown runner, no roster match).
  void resolveAsNewRunner(int entryId, {String? name, int? newBib}) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    final original = _queue[idx];
    _queue[idx] = original.copyWith(
      isResolved: true,
      isNewRunner: true,
      resolvedName: name ?? 'New Runner',
      correctedBib: newBib,
    );
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

  // ── Stub data ─────────────────────────────────────────────────────────────

  List<Runner> _stubRunners() => [
        Runner(
          raceId: 1,
          bibNumber: '105',
          name: 'Alex Johnson',
          teamAbbreviation: 'MVW',
          teamColor: const Color(0xFF1565C0),
          createdAt: DateTime(2026),
        ),
        Runner(
          raceId: 1,
          bibNumber: '107',
          name: 'Ryan Smith',
          teamAbbreviation: 'ELK',
          teamColor: const Color(0xFF2E7D32),
          createdAt: DateTime(2026),
        ),
        Runner(
          raceId: 1,
          bibNumber: '112',
          name: 'Jordan Lee',
          teamAbbreviation: 'ELK',
          teamColor: const Color(0xFF2E7D32),
          createdAt: DateTime(2026),
        ),
        Runner(
          raceId: 1,
          bibNumber: '118',
          name: 'Sarah Kim',
          teamAbbreviation: 'RVS',
          teamColor: const Color(0xFFAD1457),
          createdAt: DateTime(2026),
        ),
        Runner(
          raceId: 1,
          bibNumber: '120',
          name: 'Taylor Brown',
          teamAbbreviation: 'MVW',
          teamColor: const Color(0xFF1565C0),
          createdAt: DateTime(2026),
        ),
        Runner(
          raceId: 1,
          bibNumber: '103',
          name: 'Chris Davis',
          teamAbbreviation: 'RVS',
          teamColor: const Color(0xFFAD1457),
          createdAt: DateTime(2026),
        ),
      ];
}
