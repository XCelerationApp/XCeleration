import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/services/auth_service.dart';

/// Offline-first sync scaffold
///
/// Responsibilities:
/// - Ensure local rows have UUIDs
/// - Mark writes dirty (to be called by data layer later)
/// - Push dirty rows to remote
/// - Pull changed rows from remote since last cursor and apply LWW
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _uuid = const Uuid();

  // Cursor keys
  static const String cursorRunners = 'cursor.runners';
  static const String cursorTeams = 'cursor.teams';
  static const String cursorRaces = 'cursor.races';
  static const String cursorRaceResults = 'cursor.race_results';

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _hasNormalizedSchema(Database db) async {
    final needed = [
      'runners',
      'teams',
      'races',
      'race_participants',
      'race_results'
    ];
    for (final t in needed) {
      if (!await _tableExists(db, t)) return false;
    }
    return true;
  }

  Future<void> ensureLocalUuids() async {
    final db = await DatabaseHelper.instance.databaseConn;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Sync skipped: normalized schema not found yet.');
      return;
    }
    Future<void> assignUuids(String table, String idCol) async {
      final rows = await db.query(
        table,
        columns: [idCol],
        where: "uuid IS NULL OR uuid = ''",
        limit: 1000,
      );
      for (final row in rows) {
        await db.update(
          table,
          {'uuid': _uuid.v4()},
          where: '$idCol = ?',
          whereArgs: [row[idCol]],
        );
      }
    }

    await assignUuids('runners', 'runner_id');
    await assignUuids('teams', 'team_id');
    await assignUuids('races', 'race_id');
    await assignUuids('race_results', 'result_id');
  }

  // Placeholder: persist cursors in sync_state
  Future<void> setCursor(String key, String value) async {
    final db = await DatabaseHelper.instance.databaseConn;
    await db.insert('sync_state', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCursor(String key) async {
    final db = await DatabaseHelper.instance.databaseConn;
    final rows =
        await db.query('sync_state', where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty ? rows.first['value'] as String : null;
  }

  // Public API
  Future<void> syncAll() async {
    try {
      await RemoteApiClient.instance.init();
      if (!RemoteApiClient.instance.isInitialized) {
        Logger.d('Remote not configured; skipping sync.');
        return;
      }
      // Require auth for user-scoped sync
      if (!AuthService.instance.isSignedIn) {
        Logger.d('User not signed in; skipping sync.');
        return;
      }
      await ensureLocalUuids();
      await pushAll();
      await pullAll();
    } catch (e) {
      Logger.d('Sync error: $e');
      rethrow;
    }
  }

  // Push dirty rows (scaffold only; integrate with remote client later)
  Future<void> pushAll() async {
    final client = RemoteApiClient.instance.client;
    final db = await DatabaseHelper.instance.databaseConn;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Push skipped: normalized schema not found yet.');
      return;
    }

    Future<void> pushTable(String table, String onConflict) async {
      final rows = await db.query(table, where: 'is_dirty = 1');
      if (rows.isEmpty) return;
      final payload = rows.map((m) {
        final copy = Map<String, dynamic>.from(m);
        copy.remove('is_dirty');
        final uid = AuthService.instance.currentUserId;
        if (uid != null) copy['owner_user_id'] = uid;
        return copy;
      }).toList();
      await client.from(table).upsert(payload, onConflict: onConflict);
      final uuids = payload.map((r) => r['uuid']).whereType<String>().toList();
      if (uuids.isNotEmpty) {
        final qMarks = List.filled(uuids.length, '?').join(',');
        await db.rawUpdate(
            'UPDATE $table SET is_dirty = 0 WHERE uuid IN ($qMarks)', uuids);
      }
    }

    await pushTable('runners', 'uuid');
    await pushTable('teams', 'uuid');
    await pushTable('races', 'uuid');
    await pushTable('race_results', 'uuid');
  }

  // Pull changed rows (scaffold only)
  Future<void> pullAll() async {
    final client = RemoteApiClient.instance.client;
    final db = await DatabaseHelper.instance.databaseConn;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Pull skipped: normalized schema not found yet.');
      return;
    }

    // Determine accessible owners: self plus any linked coaches (if feature present)
    Future<List<String>> getAccessibleOwnerIds() async {
      final uid = AuthService.instance.currentUserId;
      if (uid == null) return [];
      try {
        // Optional table `coach_links(coach_user_id, viewer_user_id)`
        final List links = await client
            .from('coach_links')
            .select('coach_user_id')
            .eq('viewer_user_id', uid);
        final coachIds = links
            .map((e) => (e as Map)['coach_user_id']?.toString())
            .whereType<String>()
            .toList();
        return [uid, ...coachIds];
      } catch (_) {
        // If table doesn't exist yet, just return self
        return [uid];
      }
    }

    final accessibleOwnerIds = await getAccessibleOwnerIds();

    Future<void> pullTable(String table, String idCol) async {
      final cursorKey = 'cursor.$table';
      final cursor = await getCursor(cursorKey);
      final query = client.from(table).select();
      if (accessibleOwnerIds.isNotEmpty) {
        if (accessibleOwnerIds.length == 1) {
          query.eq('owner_user_id', accessibleOwnerIds.first);
        } else {
          final orExpr =
              accessibleOwnerIds.map((id) => 'owner_user_id.eq.$id').join(',');
          query.or(orExpr);
        }
      }
      if (cursor != null && cursor.isNotEmpty) {
        query.gt('updated_at', cursor);
      }
      final List data = await query.order('updated_at').limit(1000);
      String? newCursor = cursor;
      for (final row in data) {
        final remote = Map<String, dynamic>.from(row as Map);
        final uuid = remote['uuid'] as String?;
        if (uuid == null) continue;
        final locals =
            await db.query(table, where: 'uuid = ?', whereArgs: [uuid]);
        // Remove remote-only fields not present locally
        remote.remove('owner_user_id');
        if (locals.isEmpty) {
          final insert = Map<String, dynamic>.from(remote);
          insert['is_dirty'] = 0;
          await db.insert(table, insert,
              conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final local = locals.first;
          final localUpdated =
              DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          final remoteUpdated =
              DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          if (remoteUpdated.isAfter(localUpdated)) {
            final update = Map<String, dynamic>.from(remote);
            update['is_dirty'] = 0;
            await db
                .update(table, update, where: 'uuid = ?', whereArgs: [uuid]);
          }
        }
        final updatedAtStr = remote['updated_at']?.toString();
        if (updatedAtStr != null &&
            (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
          newCursor = updatedAtStr;
        }
      }
      if (newCursor != null && newCursor != cursor) {
        await setCursor(cursorKey, newCursor);
      }
    }

    await pullTable('runners', 'runner_id');
    await pullTable('teams', 'team_id');
    await pullTable('races', 'race_id');
    await pullTable('race_results', 'result_id');
  }
}
