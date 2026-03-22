/// A domain-level correction message from the Fixer to the Bib Recorder.
///
/// Carries all the data needed to update a [BibEntry] after the Fixer
/// resolves an entry. [entryId] identifies the entry by its finish position
/// (the shared key across devices). [correctedBib] is null when the resolution
/// does not change the bib number (e.g. new-runner creation with no bib edit).
class BibCorrectionMessage {
  const BibCorrectionMessage({
    required this.entryId,
    required this.originalBib,
    this.correctedBib,
    this.resolvedName,
    this.isNewRunner = false,
  });

  /// Finish position of the originating entry — shared key between Fixer and
  /// Bib Recorder.
  final int entryId;

  /// The bib number that was originally recorded (before correction).
  final int originalBib;

  /// The corrected bib number, or null when only runner identity changed.
  final int? correctedBib;

  /// Display name of the matched or newly created runner, if any.
  final String? resolvedName;

  /// True when the resolution created a new runner record.
  final bool isNewRunner;

  BibCorrectionMessage copyWith({
    int? entryId,
    int? originalBib,
    int? correctedBib,
    String? resolvedName,
    bool? isNewRunner,
  }) =>
      BibCorrectionMessage(
        entryId: entryId ?? this.entryId,
        originalBib: originalBib ?? this.originalBib,
        correctedBib: correctedBib ?? this.correctedBib,
        resolvedName: resolvedName ?? this.resolvedName,
        isNewRunner: isNewRunner ?? this.isNewRunner,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibCorrectionMessage &&
        other.entryId == entryId &&
        other.originalBib == originalBib &&
        other.correctedBib == correctedBib &&
        other.resolvedName == resolvedName &&
        other.isNewRunner == isNewRunner;
  }

  @override
  int get hashCode => Object.hash(
        entryId,
        originalBib,
        correctedBib,
        resolvedName,
        isNewRunner,
      );
}
