import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/services/phonetic_search.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';

/// Controls the Fixer role.
///
/// The Fixer resolves entries that the Bib Recorder flagged as DUPLICATE /
/// UNKNOWN, or that the Verifier explicitly rejected. Resolution options:
///   • Match to an existing runner (via fuzzy name search)
///   • Correct the bib number directly
///   • Create a new runner record
///
/// In the UI-first build the queue and runner roster are seeded from stub data.
/// TODO(XCE-230): populate queue from Verifier P2P session + Bib Recorder flags
/// TODO(XCE-230): load runners from AssistantStorageService
class FixerController extends ChangeNotifier {
  FixerController();

  final List<FixerEntry> _queue = [];
  final List<Runner> _allRunners = [];
  List<Runner> _searchResults = [];
  String _searchQuery = '';
  bool _inRace = false;

  List<FixerEntry> get queue => List.unmodifiable(_queue);
  List<Runner> get searchResults => List.unmodifiable(_searchResults);
  String get searchQuery => _searchQuery;

  int get unresolvedCount => _queue.where((e) => !e.isResolved).length;
  bool get isInRace => _inRace;

  void initialize() {
    // No-op for now; real init will subscribe to Verifier P2P session.
  }

  /// Enter a race session (populates stub data until P2P is wired up).
  void joinRace() {
    _inRace = true;
    _allRunners.addAll(_stubRunners());
    _queue.addAll(_stubQueue());
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
    final correctedBib = int.tryParse(runner.bibNumber) ?? _queue[idx].bib;
    _queue[idx] = _queue[idx].copyWith(
      isResolved: true,
      correctedBib: correctedBib,
      resolvedName: runner.name ?? runner.bibNumber,
    );
    // TODO(XCE-230): back-propagate correction to Bib Recorder via P2P
    notifyListeners();
  }

  /// Resolve by entering the correct bib number directly.
  void resolveWithBib(int entryId, int newBib) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    _queue[idx] = _queue[idx].copyWith(isResolved: true, correctedBib: newBib);
    // TODO(XCE-230): back-propagate correction to Bib Recorder via P2P
    notifyListeners();
  }

  /// Resolve by creating a new runner record (unknown runner, no roster match).
  void resolveAsNewRunner(int entryId, {String? name, int? newBib}) {
    final idx = _queue.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;
    _queue[idx] = _queue[idx].copyWith(
      isResolved: true,
      isNewRunner: true,
      resolvedName: name ?? 'New Runner',
      correctedBib: newBib,
    );
    // TODO(XCE-230): persist new runner via storage and notify Bib Recorder
    notifyListeners();
  }

  // ── Stub data ─────────────────────────────────────────────────────────────

  List<FixerEntry> _stubQueue() => const [
        FixerEntry(
          id: 1,
          position: 2,
          bib: 107,
          reason: FixReason.unknown,
        ),
        FixerEntry(
          id: 2,
          position: 4,
          bib: 105,
          runnerName: 'Johnson, Alex',
          reason: FixReason.duplicate,
        ),
        FixerEntry(
          id: 3,
          position: 7,
          bib: 199,
          reason: FixReason.verifierFlagged,
        ),
      ];

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
