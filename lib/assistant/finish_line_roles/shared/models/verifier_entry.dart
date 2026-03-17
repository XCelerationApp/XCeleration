import 'package:flutter/material.dart';

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
    this.runnerName,
    this.teamAbbreviation,
    this.teamColor,
    this.flag = BibFlag.none,
    this.status = VerificationStatus.pending,
  });

  /// Matches [BibEntry.id] from the Bib Recorder.
  final int id;

  /// Finish-line position (1 = first across).
  final int position;

  final int bib;
  final String? runnerName;
  final String? teamAbbreviation;
  final Color? teamColor;
  final BibFlag flag;
  final VerificationStatus status;

  VerifierEntry copyWith({VerificationStatus? status}) => VerifierEntry(
        id: id,
        position: position,
        bib: bib,
        runnerName: runnerName,
        teamAbbreviation: teamAbbreviation,
        teamColor: teamColor,
        flag: flag,
        status: status ?? this.status,
      );
}
