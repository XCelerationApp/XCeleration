import 'dart:async';
import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';

/// Controls the Verifier role.
///
/// When an entry is actioned (verify / flag / skip) it stays in [entries] in
/// an acted state for 3 seconds so the verifier can undo. After the timer
/// fires the entry is committed to [history] and counted in the stats.
///
/// TODO(XCE-230): replace stub init with real-time feed from the Bib Recorder
///                over a P2P_POINT_TO_POINT session.
class VerifierController extends ChangeNotifier {
  VerifierController();

  final List<VerifierEntry> _entries = [];
  final List<VerifierEntry> _history = [];
  final Map<int, Timer> _undoTimers = {};
  bool _inRace = false;

  /// Active queue — pending entries plus any recently actioned (within 3 s).
  List<VerifierEntry> get entries => List.unmodifiable(_entries);

  bool get isInRace => _inRace;

  // ── Stats (committed to history only) ────────────────────────────────────

  int get confirmed =>
      _history.where((e) => e.status == VerificationStatus.verified).length;
  int get wrong =>
      _history.where((e) => e.status == VerificationStatus.flagged).length;
  int get skipped =>
      _history.where((e) => e.status == VerificationStatus.skipped).length;
  int get pending =>
      _entries.where((e) => e.status == VerificationStatus.pending).length;

  void initialize() {
    // No-op for now; real init will subscribe to Bib Recorder P2P session.
  }

  /// Enter a race session (populates stub data until P2P is wired up).
  void joinRace() {
    _inRace = true;
    _entries.addAll(_stubEntries());
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// ✓ — runner confirmed; name matches bib.
  void verify(int id) => _act(id, VerificationStatus.verified);

  /// ✗ — runner could not be confirmed; escalate to Fixer.
  void flag(int id) {
    _act(id, VerificationStatus.flagged);
    // TODO(XCE-230): forward entry to Fixer via P2P session
  }

  /// — — skip / defer.
  void skip(int id) => _act(id, VerificationStatus.skipped);

  /// Cancel the commit timer and revert the entry to pending.
  void undo(int id) {
    _undoTimers[id]?.cancel();
    _undoTimers.remove(id);
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(status: VerificationStatus.pending);
    notifyListeners();
  }

  void _act(int id, VerificationStatus status) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(status: status);
    notifyListeners();

    _undoTimers[id]?.cancel();
    _undoTimers[id] = Timer(const Duration(seconds: 3), () {
      if (_undoTimers.containsKey(id)) {
        _undoTimers.remove(id);
        final entry = _entries.where((e) => e.id == id).firstOrNull;
        if (entry != null) {
          _history.insert(0, entry);
          _entries.removeWhere((e) => e.id == id);
        }
        notifyListeners();
      }
    });
  }

  void leaveRace() {
    for (final t in _undoTimers.values) {
      t.cancel();
    }
    _undoTimers.clear();
    _entries.clear();
    _history.clear();
    _inRace = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _undoTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  // ── Stub data ─────────────────────────────────────────────────────────────

  List<VerifierEntry> _stubEntries() => [
        const VerifierEntry(
          id: 1,
          position: 1,
          bib: 107,
          runnerName: 'Priya Singh',
          teamAbbreviation: 'RIV',
          teamColor: Color(0xFF43A047),
        ),
        const VerifierEntry(
          id: 2,
          position: 2,
          bib: 101,
          runnerName: 'Marcus Webb',
          teamAbbreviation: 'WES',
          teamColor: Color(0xFF8E24AA),
        ),
        const VerifierEntry(
          id: 3,
          position: 3,
          bib: 23,
          flag: BibFlag.unknown,
        ),
        const VerifierEntry(
          id: 4,
          position: 4,
          bib: 110,
          runnerName: 'Jalen Moore',
          teamAbbreviation: 'WES',
          teamColor: Color(0xFF8E24AA),
        ),
        const VerifierEntry(
          id: 5,
          position: 5,
          bib: 103,
          runnerName: 'Elena Cruz',
          teamAbbreviation: 'WES',
          teamColor: Color(0xFF8E24AA),
        ),
        const VerifierEntry(
          id: 6,
          position: 6,
          bib: 108,
          runnerName: 'Tom Gallagher',
          teamAbbreviation: 'PIN',
          teamColor: Color(0xFFFB8C00),
        ),
        const VerifierEntry(
          id: 7,
          position: 7,
          bib: 107,
          runnerName: 'Priya Singh',
          teamAbbreviation: 'RIV',
          teamColor: Color(0xFF43A047),
          flag: BibFlag.duplicate,
        ),
        const VerifierEntry(
          id: 8,
          position: 8,
          bib: 111,
          runnerName: 'Rosa Vega',
          teamAbbreviation: 'LAK',
          teamColor: Color(0xFF1E88E5),
        ),
      ];
}
