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
}
