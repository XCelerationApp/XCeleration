import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_session_service.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/race_data_loader.dart';
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/services/haptic_feedback_service.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Controls the Verifier role.
///
/// When an entry is actioned (verify / flag / skip) it stays in [entries] in
/// an acted state for 3 seconds so the verifier can undo. After the timer
/// fires the entry is committed to [history] and counted in the stats.
class VerifierController extends ChangeNotifier {
  VerifierController({
    P2PSessionService? session,
    IAssistantStorageService? storage,
    IHapticFeedback? haptic,
  })  : _session = session,
        _storage = storage,
        _haptic = haptic ?? HapticFeedbackService();

  P2PSessionService? _session;
  final IAssistantStorageService? _storage;
  final IHapticFeedback _haptic;

  final List<VerifierEntry> _entries = [];
  final List<VerifierEntry> _history = [];
  final Map<int, Timer> _undoTimers = {};
  // What each pending undo timer does when it fires, so leaving the race can
  // commit it early instead of dropping it.
  final Map<int, VoidCallback> _pendingCommits = {};
  StreamSubscription<(Role, MessageEnvelope)>? _sessionSub;
  bool _inRace = false;

  List<RaceRecord> _races = [];

  /// Active queue — pending entries plus any recently actioned (within 3 s).
  List<VerifierEntry> get entries => List.unmodifiable(_entries);

  bool get isInRace => _inRace;

  /// Locally stored races loaded from storage (pre-loaded from Coach).
  List<RaceRecord> get races => List.unmodifiable(_races);

  // ── Stats (committed to history only) ────────────────────────────────────

  int get confirmed =>
      _history.where((e) => e.status == VerificationStatus.verified).length;
  int get wrong =>
      _history.where((e) => e.status == VerificationStatus.flagged).length;
  int get skipped =>
      _history.where((e) => e.status == VerificationStatus.skipped).length;
  int get pending =>
      _entries.where((e) => e.status == VerificationStatus.pending).length;

  Future<void> initialize() async {
    if (_session != null) {
      _sessionSub = _session!.incomingMessages.listen(_onSessionMessage);
    }
    await _loadRaces();
  }

  Future<void> _loadRaces() async {
    if (_storage == null) return;
    final result = await _storage.getRaces(DeviceName.verifier.toString());
    switch (result) {
      case Success(:final value):
        _races = value;
      case Failure(:final error):
        Logger.e('[VerifierController._loadRaces] ${error.originalException}');
    }
    notifyListeners();
  }

  // ── Race loading ──────────────────────────────────────────────────────────

  /// Parses [data] received from the Coach and saves the race and runners to
  /// local storage.
  Future<Result<void>> processLoadedRaceData(String data) async {
    if (_storage == null) {
      return Failure(const AppError(userMessage: 'Storage not available'));
    }
    return processLoadedRaceDataShared(
      data: data,
      deviceName: DeviceName.verifier,
      storage: _storage,
      onComplete: _loadRaces,
    );
  }

  int _raceId = 0;

  /// Enter a race session and recover any persisted entries.
  ///
  /// Entries that arrived while connecting are kept: they belong to this race
  /// and the Bib Recorder will not resend them.
  Future<void> joinRace({required int raceId}) async {
    _setRace(raceId);
    _inRace = true;
    notifyListeners();
    if (_storage == null) return;
    final result = await _storage.getVerifierEntries(raceId);
    if (result case Success(:final value)) {
      final known = {..._entries, ..._history}.map((e) => e.id).toSet();
      for (final entry in value) {
        if (known.contains(entry.id)) continue;
        if (entry.status == VerificationStatus.pending) {
          _entries.add(entry);
        } else {
          _history.add(entry);
        }
      }
      // Newest finisher first, matching how live entries are inserted.
      _entries.sort((a, b) => b.position.compareTo(a.position));
      notifyListeners();
    }
  }

  /// Points the controller at [raceId], dropping another race's entries.
  void _setRace(int raceId) {
    if (_raceId == raceId) return;
    _commitPending();
    _entries.clear();
    _history.clear();
    _raceId = raceId;
  }

  /// Fires every open undo window now, so a flag made just before leaving
  /// still reaches the Fixer.
  void _commitPending() {
    for (final timer in _undoTimers.values) {
      timer.cancel();
    }
    _undoTimers.clear();
    final commits = List.of(_pendingCommits.values);
    _pendingCommits.clear();
    for (final commit in commits) {
      commit();
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// ✓ — runner confirmed; name matches bib.
  void verify(int id) {
    unawaited(_haptic.lightImpact());
    _act(id, VerificationStatus.verified);
  }

  /// ✗ — runner could not be confirmed; escalate to Fixer.
  ///
  /// The P2P message to the Fixer is sent only after the 3-second undo window
  /// expires. If [undo] is called before the timer fires, no message is sent.
  void flag(int id) {
    unawaited(_haptic.vibrate());
    final idx = _entries.indexWhere((e) => e.id == id);
    VoidCallback? onCommit;
    if (_session != null && idx != -1) {
      final e = _entries[idx];
      final reason = switch (e.flag) {
        BibFlag.unknown => FlagReason.unknown,
        BibFlag.duplicate => FlagReason.duplicate,
        BibFlag.none => FlagReason.wrongName,
      };
      final message = MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
        entry: BibEntryMessage(
          finishPosition: e.position,
          bib: e.bib,
          status: _bibEntryStatusFor(e.flag),
          timestamp: DateTime.now(),
          entryId: e.entryId,
        ),
        reason: reason,
      ));
      onCommit = () => unawaited(_session!.sendMessage(Role.fixer, message));
    }
    _act(id, VerificationStatus.flagged, onCommit: onCommit);
  }

  /// — — skip / defer.
  void skip(int id) {
    unawaited(_haptic.lightImpact());
    _act(id, VerificationStatus.skipped);
  }

  /// Cancel the commit timer and revert the entry to pending.
  void undo(int id) {
    _undoTimers.remove(id)?.cancel();
    _pendingCommits.remove(id);
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(status: VerificationStatus.pending);
    if (_storage != null) {
      unawaited(_storage.updateVerifierEntryStatus(_raceId, id, VerificationStatus.pending).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[VerifierController.undo] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  void _act(int id, VerificationStatus status, {VoidCallback? onCommit}) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _entries[idx] = _entries[idx].copyWith(status: status);
    if (_storage != null) {
      unawaited(_storage.updateVerifierEntryStatus(_raceId, id, status).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[VerifierController._act] ${error.originalException}');
        }
      }));
    }
    notifyListeners();

    void commit() {
      onCommit?.call();
      final entry = _entries.where((e) => e.id == id).firstOrNull;
      if (entry != null) {
        _history.insert(0, entry);
        _entries.removeWhere((e) => e.id == id);
      }
    }

    _undoTimers.remove(id)?.cancel();
    _pendingCommits[id] = commit;
    _undoTimers[id] = Timer(const Duration(seconds: 3), () {
      _undoTimers.remove(id);
      _pendingCommits.remove(id)?.call();
      notifyListeners();
    });
  }

  /// Leaves the race. Call before disposing the session so pending flags can
  /// still be sent.
  void leaveRace() {
    _commitPending();
    _entries.clear();
    _history.clear();
    _inRace = false;
    notifyListeners();
  }

  Future<void> deleteRaceFromLobby(int raceId) async {
    if (_storage == null) return;
    final result = await _storage.deleteRace(raceId, DeviceName.verifier.toString());
    switch (result) {
      case Success():
        _races.removeWhere((r) => r.raceId == raceId);
        notifyListeners();
      case Failure(:final error):
        Logger.e('[VerifierController.deleteRaceFromLobby] ${error.originalException}');
    }
  }

  // ── P2P ───────────────────────────────────────────────────────────────────

  /// Attaches [session] to this controller for the current race.
  ///
  /// Safe to call after [initialize]. Cancels any existing session subscription
  /// before subscribing to [session]'s incoming messages.
  void attachSession(P2PSessionService session, {required int raceId}) {
    // Set the race first: entries can arrive before the user taps Start.
    _setRace(raceId);
    _sessionSub?.cancel();
    if (_session != null && _session != session) _session!.dispose();
    _session = session;
    _sessionSub = session.incomingMessages.listen(_onSessionMessage);
  }

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    try {
      switch (envelope.type) {
        case MessageType.bibEntry:
          _addEntryFromMessage(envelope.decode() as BibEntryMessage);
        case MessageType.bibEntryDeleted:
          _removeEntry((envelope.decode() as BibEntryDeletedMessage).entryId);
      }
    } catch (e) {
      Logger.e('[VerifierController._onSessionMessage] Malformed message dropped: $e');
    }
  }

  void _addEntryFromMessage(BibEntryMessage msg) {
    final entry = VerifierEntry.fromMessage(msg);
    final existing = _entries.where((e) => e.id == entry.id).firstOrNull ??
        _history.where((e) => e.id == entry.id).firstOrNull;
    if (existing != null) {
      // A re-delivery of the same entry keeps the decision already made.
      if (existing.bib == entry.bib && existing.flag == entry.flag) return;
      // The Bib Recorder edited the entry, so it needs verifying again.
      _undoTimers.remove(entry.id)?.cancel();
      _pendingCommits.remove(entry.id);
      _entries.removeWhere((e) => e.id == entry.id);
      _history.removeWhere((e) => e.id == entry.id);
    }
    _entries.insert(0, entry);
    if (_storage != null) {
      unawaited(_storage.saveVerifierEntry(_raceId, entry).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[VerifierController._addEntryFromMessage] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  void _removeEntry(int entryId) {
    // Cancel without committing: a pending flag for a deleted entry must not
    // reach the Fixer.
    _undoTimers.remove(entryId)?.cancel();
    _pendingCommits.remove(entryId);
    final before = _entries.length + _history.length;
    _entries.removeWhere((e) => e.id == entryId);
    _history.removeWhere((e) => e.id == entryId);
    if (_entries.length + _history.length == before) return;
    if (_storage != null) {
      unawaited(_storage.deleteVerifierEntry(_raceId, entryId).then((result) {
        if (result case Failure(:final error)) {
          Logger.e('[VerifierController._removeEntry] ${error.originalException}');
        }
      }));
    }
    notifyListeners();
  }

  static BibEntryStatus _bibEntryStatusFor(BibFlag flag) => switch (flag) {
        BibFlag.duplicate => BibEntryStatus.duplicate,
        BibFlag.unknown => BibEntryStatus.unknown,
        BibFlag.none => BibEntryStatus.resolved,
      };

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _commitPending();
    _sessionSub?.cancel();
    _session?.dispose();
    super.dispose();
  }
}
