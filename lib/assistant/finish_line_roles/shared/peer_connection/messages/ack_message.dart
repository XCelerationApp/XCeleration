/// Transport-level acknowledgement sent by the receiver after processing any
/// non-ACK [MessageEnvelope] to confirm delivery.
///
/// Never emitted on [P2PSessionService.incomingMessages] — the service handles
/// ACKs internally.
class AckMessage {
  const AckMessage({required this.sequence});

  /// The [MessageEnvelope.sequence] being acknowledged.
  final int sequence;
}
