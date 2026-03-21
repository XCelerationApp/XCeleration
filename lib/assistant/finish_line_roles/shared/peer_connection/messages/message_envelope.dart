import 'bib_entry_message.dart';
import 'fixer_correction_message.dart';
import 'verifier_flag_message.dart';

/// Current wire-format version. Increment when the schema changes in a
/// backwards-incompatible way.
const int messageSchemaVersion = 1;

/// Type discriminator constants used in [MessageEnvelope.type].
class MessageType {
  MessageType._();

  static const bibEntry = 'bib_entry';
  static const verifierFlag = 'verifier_flag';
  static const fixerCorrection = 'fixer_correction';
}

/// Wraps any finish-line message with a type discriminator and schema version,
/// so the receiver can route the payload before deserialising it.
class MessageEnvelope {
  const MessageEnvelope({
    required this.type,
    required this.version,
    required this.payload,
  });

  /// One of the [MessageType] constants.
  final String type;

  /// Schema version — always [messageSchemaVersion] for newly created envelopes.
  final int version;

  /// Raw JSON payload. Use [decode] to obtain the typed message.
  final Map<String, dynamic> payload;

  // --- factories -----------------------------------------------------------

  factory MessageEnvelope.wrapBibEntry(BibEntryMessage msg) => MessageEnvelope(
        type: MessageType.bibEntry,
        version: messageSchemaVersion,
        payload: msg.toJson(),
      );

  factory MessageEnvelope.wrapVerifierFlag(VerifierFlagMessage msg) =>
      MessageEnvelope(
        type: MessageType.verifierFlag,
        version: messageSchemaVersion,
        payload: msg.toJson(),
      );

  factory MessageEnvelope.wrapFixerCorrection(FixerCorrectionMessage msg) =>
      MessageEnvelope(
        type: MessageType.fixerCorrection,
        version: messageSchemaVersion,
        payload: msg.toJson(),
      );

  // --- JSON ----------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'type': type,
        'version': version,
        'payload': payload,
      };

  factory MessageEnvelope.fromJson(Map<String, dynamic> json) =>
      MessageEnvelope(
        type: json['type'] as String,
        version: json['version'] as int,
        payload: json['payload'] as Map<String, dynamic>,
      );

  // --- routing -------------------------------------------------------------

  /// Decodes [payload] into the correct typed message based on [type].
  ///
  /// Returns one of:
  /// - [BibEntryMessage]
  /// - [VerifierFlagMessage]
  /// - [FixerCorrectionMessage]
  ///
  /// Throws [ArgumentError] for unknown type discriminators.
  Object decode() => switch (type) {
        MessageType.bibEntry => BibEntryMessage.fromJson(payload),
        MessageType.verifierFlag => VerifierFlagMessage.fromJson(payload),
        MessageType.fixerCorrection => FixerCorrectionMessage.fromJson(payload),
        _ => throw ArgumentError('Unknown message type: $type'),
      };
}
