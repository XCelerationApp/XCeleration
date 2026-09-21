import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/peer_connection/messages/messages.dart';
import 'package:xceleration/shared/role_bar/models/role_enums.dart';

/// Durable store for P2P messages that a peer has not acknowledged yet.
///
/// [P2PSessionService] adds every message when it is stamped and removes it
/// when the peer ACKs it, so messages survive the app being killed while a
/// peer is out of range and are re-sent on the next connection.
abstract interface class IP2POutbox {
  /// Unacknowledged messages sent by [localRole] for [raceId], in sequence
  /// order, paired with the role they are addressed to.
  Future<List<(Role, MessageEnvelope)>> load(int raceId, Role localRole);

  Future<void> add(
      int raceId, Role localRole, Role target, MessageEnvelope stamped);

  Future<void> remove(int raceId, Role localRole, Role target, int sequence);
}

/// [IP2POutbox] backed by the `p2p_outbox` table in the assistant database.
class SqliteP2POutbox implements IP2POutbox {
  SqliteP2POutbox(this._database);

  final Future<Database> Function() _database;

  static const table = 'p2p_outbox';

  static const createTableSql = '''
    CREATE TABLE IF NOT EXISTS p2p_outbox (
      race_id INTEGER NOT NULL,
      local_role TEXT NOT NULL,
      target_role TEXT NOT NULL,
      sequence INTEGER NOT NULL,
      envelope TEXT NOT NULL,
      PRIMARY KEY (race_id, local_role, target_role, sequence)
    )
  ''';

  @override
  Future<List<(Role, MessageEnvelope)>> load(int raceId, Role localRole) async {
    final db = await _database();
    final rows = await db.query(
      table,
      where: 'race_id = ? AND local_role = ?',
      whereArgs: [raceId, localRole.name],
      orderBy: 'sequence ASC',
    );
    return [
      for (final row in rows)
        (
          Role.values.byName(row['target_role'] as String),
          MessageEnvelope.fromJson(
            (jsonDecode(row['envelope'] as String) as Map)
                .cast<String, dynamic>(),
          ),
        ),
    ];
  }

  @override
  Future<void> add(
      int raceId, Role localRole, Role target, MessageEnvelope stamped) async {
    final db = await _database();
    await db.insert(
      table,
      {
        'race_id': raceId,
        'local_role': localRole.name,
        'target_role': target.name,
        'sequence': stamped.sequence,
        'envelope': jsonEncode(stamped.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(
      int raceId, Role localRole, Role target, int sequence) async {
    final db = await _database();
    await db.delete(
      table,
      where: 'race_id = ? AND local_role = ? AND target_role = ? AND sequence = ?',
      whereArgs: [raceId, localRole.name, target.name, sequence],
    );
  }
}
