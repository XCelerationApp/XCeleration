import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/p2p_outbox.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// In-memory [IP2POutbox] for tests.
class MemoryP2POutbox implements IP2POutbox {
  final Map<(int, Role, Role, int), MessageEnvelope> messages = {};

  @override
  Future<List<(Role, MessageEnvelope)>> load(int raceId, Role localRole) async {
    final keys = messages.keys
        .where((k) => k.$1 == raceId && k.$2 == localRole)
        .toList()
      ..sort((a, b) => a.$4.compareTo(b.$4));
    return [for (final k in keys) (k.$3, messages[k]!)];
  }

  @override
  Future<void> add(
      int raceId, Role localRole, Role target, MessageEnvelope stamped) async {
    messages[(raceId, localRole, target, stamped.sequence!)] = stamped;
  }

  @override
  Future<void> remove(
      int raceId, Role localRole, Role target, int sequence) async {
    messages.remove((raceId, localRole, target, sequence));
  }
}
