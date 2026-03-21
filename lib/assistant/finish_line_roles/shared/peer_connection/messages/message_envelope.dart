import 'ack_message.dart';
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

  /// Transport-level ACK — never surfaced to [P2PSessionService.incomingMessages].
  static const ack = 'ack';
}

/// Wraps any finish-line message with a type discriminator and schema version,
/// so the receiver can route the payload before deserialising it.
class MessageEnvelope {
  const MessageEnvelope({
    required this.type,
    required this.version,
    required this.payload,
    this.sequence,
  });

  /// One of the [MessageType] constants.
  final String type;

  /// Schema version — always [messageSchemaVersion] for newly created envelopes.
  final int version;

  /// Raw JSON payload. Use [decode] to obtain the typed message.
  final Map<String, dynamic> payload;

  /// Monotonically-increasing sequence number assigned by the sender.
  ///
  /// Nullable so that envelopes created before this field existed remain
  /// decodable without changes. When present, the receiver uses it to
  /// deduplicate re-deliveries and the sender uses it to track pending ACKs.
  final int? sequence;

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

  /// Creates a transport-level ACK envelope for [sequence].
  ///
  /// ACK envelopes are intercepted by [P2PSessionService] and never emitted
  /// to [P2PSessionService.incomingMessages].
  factory MessageEnvelope.wrapAck(int sequence) => MessageEnvelope(
        type: MessageType.ack,
        version: messageSchemaVersion,
        payload: const {},
        sequence: sequence,
      );

  /// Returns a copy of this envelope with [seq] stamped as the sequence number.
  MessageEnvelope withSequence(int seq) => MessageEnvelope(
        type: type,
        version: version,
        payload: payload,
        sequence: seq,
      );

  // --- JSON ----------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'type': type,
        'version': version,
        'payload': payload,
        if (sequence != null) 'sequence': sequence,
      };

  factory MessageEnvelope.fromJson(Map<String, dynamic> json) =>
      MessageEnvelope(
        type: json['type'] as String,
        version: json['version'] as int,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        sequence: json['sequence'] as int?,
      );

  // --- routing -------------------------------------------------------------

  /// Decodes [payload] into the correct typed message based on [type].
  ///
  /// Returns one of:
  /// - [BibEntryMessage]
  /// - [VerifierFlagMessage]
  /// - [FixerCorrectionMessage]
  /// - [AckMessage]
  ///
  /// Throws [ArgumentError] for unknown type discriminators.
  Object decode() => switch (type) {
        MessageType.bibEntry => BibEntryMessage.fromJson(payload),
        MessageType.verifierFlag => VerifierFlagMessage.fromJson(payload),
        MessageType.fixerCorrection => FixerCorrectionMessage.fromJson(payload),
        MessageType.ack => AckMessage(sequence: sequence!),
        _ => throw ArgumentError('Unknown message type: $type'),
      };
}
