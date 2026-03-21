/// How the Fixer resolved a flagged entry.
enum CorrectionType {
  matched,
  bibCorrected,
  newRunner;

  static const _wireValues = {
    matched: 'matched',
    bibCorrected: 'bib_corrected',
    newRunner: 'new_runner',
  };

  static const _fromWire = {
    'matched': matched,
    'bib_corrected': bibCorrected,
    'new_runner': newRunner,
  };

  String get wireValue => _wireValues[this]!;

  static CorrectionType fromWireValue(String value) {
    final result = _fromWire[value];
    if (result == null) throw ArgumentError('Unknown CorrectionType: $value');
    return result;
  }
}

/// A correction back-propagated by the Fixer, sent Fixer → BibRecorderV2.
class FixerCorrectionMessage {
  const FixerCorrectionMessage({
    required this.finishPosition,
    required this.originalBib,
    required this.correctedBib,
    this.matchedRunnerId,
    required this.correctionType,
  });

  final int finishPosition;
  final int originalBib;
  final int correctedBib;

  /// The ID of the matched runner, or null when no roster match was found.
  final int? matchedRunnerId;

  final CorrectionType correctionType;

  Map<String, dynamic> toJson() => {
        'finish_position': finishPosition,
        'original_bib': originalBib,
        'corrected_bib': correctedBib,
        'matched_runner_id': matchedRunnerId,
        'correction_type': correctionType.wireValue,
      };

  factory FixerCorrectionMessage.fromJson(Map<String, dynamic> json) =>
      FixerCorrectionMessage(
        finishPosition: json['finish_position'] as int,
        originalBib: json['original_bib'] as int,
        correctedBib: json['corrected_bib'] as int,
        matchedRunnerId: json['matched_runner_id'] as int?,
        correctionType: CorrectionType.fromWireValue(
          json['correction_type'] as String,
        ),
      );
}
