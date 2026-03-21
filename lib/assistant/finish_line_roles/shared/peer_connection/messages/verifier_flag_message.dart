import 'bib_entry_message.dart';

/// Why the Verifier flagged an entry for the Fixer.
enum FlagReason {
  wrongName,
  unknown,
  duplicate;

  static const _wireValues = {
    wrongName: 'wrong_name',
    unknown: 'unknown',
    duplicate: 'duplicate',
  };

  static const _fromWire = {
    'wrong_name': wrongName,
    'unknown': unknown,
    'duplicate': duplicate,
  };

  String get wireValue => _wireValues[this]!;

  static FlagReason fromWireValue(String value) {
    final result = _fromWire[value];
    if (result == null) throw ArgumentError('Unknown FlagReason: $value');
    return result;
  }
}

/// An entry flagged by the Verifier, sent Verifier → Fixer.
class VerifierFlagMessage {
  const VerifierFlagMessage({
    required this.entry,
    required this.reason,
  });

  final BibEntryMessage entry;
  final FlagReason reason;

  Map<String, dynamic> toJson() => {
        'entry': entry.toJson(),
        'reason': reason.wireValue,
      };

  factory VerifierFlagMessage.fromJson(Map<String, dynamic> json) =>
      VerifierFlagMessage(
        entry: BibEntryMessage.fromJson(
          json['entry'] as Map<String, dynamic>,
        ),
        reason: FlagReason.fromWireValue(json['reason'] as String),
      );
}
