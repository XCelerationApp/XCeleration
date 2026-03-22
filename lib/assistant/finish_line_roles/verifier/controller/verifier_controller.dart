import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';
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

/// Controls the Verifier role.
///
/// When an entry is actioned (verify / flag / skip) it stays in [entries] in
/// an acted state for 3 seconds so the verifier can undo. After the timer
/// fires the entry is committed to [history] and counted in the stats.
class VerifierController extends ChangeNotifier {
  VerifierController({
    P2PSessionService? session,
    IAssistantStorageService? storage,
  })  : _session = session,
        _storage = storage;

  final P2PSessionService? _session;
  final IAssistantStorageService? _storage;

  final List<VerifierEntry> _entries = [];
  final List<VerifierEntry> _history = [];
  final Map<int, Timer> _undoTimers = {};
  StreamSubscription<(Role, MessageEnvelope)>? _sessionSub;
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
    if (_session != null) {
      _sessionSub = _session.incomingMessages.listen(_onSessionMessage);
    }
  }

  // ── Race loading ──────────────────────────────────────────────────────────

  /// Parses [data] received from the Coach and saves the race and runners to
  /// local storage. Returns [Failure] with a user-readable message if parsing
  /// or saving fails.
  Future<Result<void>> processLoadedRaceData(String data) async {
    if (_storage == null) {
      return Failure(const AppError(userMessage: 'Storage not available'));
    }

    late RaceRecord raceRecord;
    List<BibDatum> loadedRunners = [];

    try {
      final parts = data.split('---');
      if (parts.length == 2) {
        raceRecord = RaceRecord.fromEncodedString(parts[0],
            type: DeviceName.verifier.toString());

        final runnersResult =
            await BibDecodeUtils.decodeEncodedRunners(parts[1]);
        switch (runnersResult) {
          case Success(:final value):
            loadedRunners = value;
          case Failure(:final error):
            Logger.e(
                '[VerifierController.processLoadedRaceData] ${error.originalException}');
            return Failure(error);
        }
      } else {
        raceRecord = RaceRecord.fromEncodedString(data,
            type: DeviceName.verifier.toString());
      }
    } catch (e) {
      Logger.e('Error parsing race data: $e');
      return Failure(AppError(userMessage: 'Failed to parse race data: $e'));
    }

    final saveResult = await _storage.saveNewRace(raceRecord);
    if (saveResult case Failure(:final error)) {
      Logger.e(
          '[VerifierController.processLoadedRaceData] ${error.originalException}');
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

    return const Success(null);
  }

  /// Enter a race session.
  void joinRace() {
    _inRace = true;
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// ✓ — runner confirmed; name matches bib.
  void verify(int id) => _act(id, VerificationStatus.verified);

  /// ✗ — runner could not be confirmed; escalate to Fixer.
  void flag(int id) {
    final idx = _entries.indexWhere((e) => e.id == id);
    _act(id, VerificationStatus.flagged);
    if (_session != null && idx != -1) {
      final e = _entries[idx];
      final reason = switch (e.flag) {
        BibFlag.unknown => FlagReason.unknown,
        BibFlag.duplicate => FlagReason.duplicate,
        BibFlag.none => FlagReason.wrongName,
      };
      unawaited(_session.sendMessage(
        Role.fixer,
        MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage(
          entry: BibEntryMessage(
            finishPosition: e.position,
            bib: e.bib,
            status: _bibEntryStatusFor(e.flag),
            timestamp: DateTime.now(),
          ),
          reason: reason,
        )),
      ));
    }
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

  // ── P2P ───────────────────────────────────────────────────────────────────

  void _onSessionMessage((Role, MessageEnvelope) event) {
    final (_, envelope) = event;
    if (envelope.type != MessageType.bibEntry) return;
    _addEntryFromMessage(envelope.decode() as BibEntryMessage);
  }

  void _addEntryFromMessage(BibEntryMessage msg) {
    _entries.insert(0, VerifierEntry.fromMessage(msg));
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
    for (final t in _undoTimers.values) {
      t.cancel();
    }
    _sessionSub?.cancel();
    super.dispose();
  }
}
