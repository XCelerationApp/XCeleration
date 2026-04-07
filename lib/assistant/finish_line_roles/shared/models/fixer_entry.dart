/// Why an entry was escalated to the Fixer.
enum FixReason { duplicate, unknown, verifierFlagged }

/// An entry in the Fixer's resolution queue.
///
/// Entries arrive from two sources:
///   • The Bib Recorder auto-escalates DUPLICATE / UNKNOWN bibs.
///   • The Verifier escalates entries the runner explicitly rejected (✗).
class FixerEntry {
  const FixerEntry({
    required this.id,
    required this.position,
    required this.bib,
    this.runnerName,
    required this.reason,
    this.isResolved = false,
    this.correctedBib,
    this.resolvedName,
    this.isNewRunner = false,
  });

  /// Matches the originating [BibEntry.id].
  final int id;

  final int position;
  final int bib;

  /// Runner name from the Bib Recorder's roster lookup, if any.
  final String? runnerName;

  final FixReason reason;
  final bool isResolved;

  /// Set when the Fixer back-propagates a bib correction.
  final int? correctedBib;

  /// Name of the runner assigned during resolution.
  final String? resolvedName;

  /// True when the entry was resolved by creating a new runner record.
  final bool isNewRunner;

  /// Human-readable context string derived from [reason] and [bib].
  String get contextMessage => switch (reason) {
        FixReason.unknown => "Marked wrong — bib doesn't match runner",
        FixReason.duplicate => 'Bib $bib already recorded — duplicate entry',
        FixReason.verifierFlagged => 'Flagged by Verifier',
      };

  FixerEntry copyWith({
    bool? isResolved,
    int? correctedBib,
    String? resolvedName,
    bool? isNewRunner,
  }) =>
      FixerEntry(
        id: id,
        position: position,
        bib: bib,
        runnerName: runnerName,
        reason: reason,
        isResolved: isResolved ?? this.isResolved,
        correctedBib: correctedBib ?? this.correctedBib,
        resolvedName: resolvedName ?? this.resolvedName,
        isNewRunner: isNewRunner ?? this.isNewRunner,
      );

  Map<String, dynamic> toMap(int raceId) => {
        'race_id': raceId,
        'entry_id': id,
        'position': position,
        'original_bib': bib.toString(),
        'runner_name': runnerName,
        'reason': reason.name,
        'is_resolved': isResolved ? 1 : 0,
        'corrected_bib': correctedBib?.toString(),
        'resolved_name': resolvedName,
        'is_new_runner': isNewRunner ? 1 : 0,
        'correction_type': null,
        'resolved_at': null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory FixerEntry.fromMap(Map<String, dynamic> map) => FixerEntry(
        id: map['entry_id'] as int,
        position: map['position'] as int,
        bib: int.parse(map['original_bib'] as String),
        runnerName: map['runner_name'] as String?,
        reason: FixReason.values.byName(map['reason'] as String),
        isResolved: (map['is_resolved'] as int) == 1,
        correctedBib: map['corrected_bib'] != null
            ? int.parse(map['corrected_bib'] as String)
            : null,
        resolvedName: map['resolved_name'] as String?,
        isNewRunner: (map['is_new_runner'] as int) == 1,
      );
}
