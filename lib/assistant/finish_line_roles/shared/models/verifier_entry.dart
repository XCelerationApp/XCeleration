import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/bib_entry_message.dart';

/// Bib flag carried over from the Bib Recorder's roster check.
enum BibFlag { none, unknown, duplicate }

/// Lifecycle of an entry in the Verifier's queue.
enum VerificationStatus { pending, verified, flagged, skipped }

/// A bib entry received from the Bib Recorder awaiting visual confirmation
/// by the Verifier stationed at the chute exit.
class VerifierEntry {
  const VerifierEntry({
    required this.id,
    required this.position,
    required this.bib,
    this.entryId,
    this.runnerName,
    this.teamAbbreviation,
    this.teamColor,
    this.flag = BibFlag.none,
    this.status = VerificationStatus.pending,
  });

  /// Matches [BibEntry.id] from the Bib Recorder.
  final int id;

  /// Original entry ID from the Bib Recorder, preserved for the correction
  /// chain back through the Fixer.
  final int? entryId;

  /// Finish-line position (1 = first across).
  final int position;

  final int bib;
  final String? runnerName;
  final String? teamAbbreviation;
  final Color? teamColor;
  final BibFlag flag;
  final VerificationStatus status;

  /// Constructs a [VerifierEntry] directly from a received [BibEntryMessage].
  ///
  /// Runner context fields are carried through from the message when present;
  /// they are null for unmatched (unknown) bibs.
  factory VerifierEntry.fromMessage(BibEntryMessage msg) {
    final flag = switch (msg.status) {
      BibEntryStatus.duplicate => BibFlag.duplicate,
      BibEntryStatus.unknown => BibFlag.unknown,
      BibEntryStatus.resolved => BibFlag.none,
    };
    return VerifierEntry(
      id: msg.entryId ?? msg.finishPosition,
      position: msg.finishPosition,
      bib: msg.bib,
      entryId: msg.entryId,
      runnerName: msg.runnerName,
      teamAbbreviation: msg.teamAbbreviation,
      teamColor: msg.teamColor != null ? Color(msg.teamColor!) : null,
      flag: flag,
    );
  }

  VerifierEntry copyWith({VerificationStatus? status}) => VerifierEntry(
        id: id,
        position: position,
        bib: bib,
        entryId: entryId,
        runnerName: runnerName,
        teamAbbreviation: teamAbbreviation,
        teamColor: teamColor,
        flag: flag,
        status: status ?? this.status,
      );

  Map<String, dynamic> toMap(int raceId) => {
        'race_id': raceId,
        'entry_id': id,
        'position': position,
        'bib_number': bib.toString(),
        'flag': flag.name,
        'status': status.name,
        'runner_name': runnerName,
        'team_abbreviation': teamAbbreviation,
        'team_color': teamColor?.toARGB32(),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory VerifierEntry.fromMap(Map<String, dynamic> map) => VerifierEntry(
        id: map['entry_id'] as int,
        position: map['position'] as int,
        bib: int.parse(map['bib_number'] as String),
        runnerName: map['runner_name'] as String?,
        teamAbbreviation: map['team_abbreviation'] as String?,
        teamColor: map['team_color'] != null
            ? Color(map['team_color'] as int)
            : null,
        flag: BibFlag.values.byName(map['flag'] as String),
        status: VerificationStatus.values.byName(map['status'] as String),
      );
}
