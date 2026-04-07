import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/i_remote_sync_client.dart';
import 'package:xceleration/core/services/i_sync_service.dart';

/// Emitted by [SyncService.syncEvents] after each successful [SyncService.pullAll].
class SyncEvent {
  const SyncEvent({
    required this.timestamp,
    required this.changedTables,
    this.changedRaceIds = const {},
  });

  /// When the pull completed.
  final DateTime timestamp;

  /// Tables that had at least one row inserted or updated during this pull.
  final Set<String> changedTables;

  /// Local race IDs whose race_results rows were inserted or updated during this pull.
  /// Non-empty only when [changedTables] contains `'race_results'`.
  final Set<int> changedRaceIds;
}

/// Helper class to track data conflicts
class _DataConflictResult {
  final bool hasConflict;
  final List<String> differences;

  _DataConflictResult(this.hasConflict, this.differences);
}

/// Helper class for push conflict checks
class _PushConflictResult {
  final bool hasConflict;
  final Map<String, dynamic> details;

  _PushConflictResult(this.hasConflict, this.details);
}

/// Offline-first sync scaffold for authenticated users
///
/// Responsibilities:
/// - Ensure local rows have UUIDs
/// - Mark writes dirty (to be called by data layer later)
/// - Push dirty rows to remote (requires authentication)
/// - Pull changed rows from remote since last cursor and apply LWW
class SyncService implements ISyncService {
  final IDatabaseConnectionProvider _db;
  final IRemoteApiClient _remote;
  final IRemoteSyncClient _syncClient;
  final IAuthService _auth;

  SyncService({
    required IDatabaseConnectionProvider db,
    required IRemoteApiClient remote,
    required IRemoteSyncClient syncClient,
    required IAuthService auth,
  })  : _db = db,
        _remote = remote,
        _syncClient = syncClient,
        _auth = auth;

  final _syncEventController = StreamController<SyncEvent>.broadcast();

  /// Emits a [SyncEvent] after each successful [pullAll] that wrote at least one row.
  @override
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

  final _uuid = const Uuid();

  // Set to true once the normalized schema is confirmed present for the first time.
  // The schema never changes at runtime after the database is opened, so this
  // cache is valid for the lifetime of the SyncService instance.
  bool _schemaNormalized = false;

  // Cursor keys
  static const String cursorRunners = 'cursor.runners';
  static const String cursorTeams = 'cursor.teams';
  static const String cursorRaces = 'cursor.races';
  static const String cursorRaceResults = 'cursor.race_results';
  static const String cursorRaceParticipants = 'cursor.race_participants';

  Future<bool> _tableExists(Database db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _hasNormalizedSchema(Database db) async {
    if (_schemaNormalized) return true;
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
    _schemaNormalized = true;
    return true;
  }

  Future<void> ensureLocalUuids() async {
    final db = await _db.database;
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
      if (rows.isEmpty) return;
      // Generate all UUIDs in Dart first, then write them in a single
      // transaction to avoid N sequential auto-commit round-trips.
      await db.transaction((txn) async {
        for (final row in rows) {
          await txn.update(
            table,
            {'uuid': _uuid.v4()},
            where: '$idCol = ?',
            whereArgs: [row[idCol]],
          );
        }
      });
    }

    await assignUuids('runners', 'runner_id');
    await assignUuids('teams', 'team_id');
    await assignUuids('races', 'race_id');
    await assignUuids('race_results', 'result_id');
    await assignUuids('race_participants', 'rowid');

    // Populate runner_uuid and race_uuid for race_results rows that are missing them
    await db.rawUpdate('''
      UPDATE race_results
      SET runner_uuid = (SELECT uuid FROM runners WHERE runners.runner_id = race_results.runner_id)
      WHERE runner_uuid IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE race_results
      SET race_uuid = (SELECT uuid FROM races WHERE races.race_id = race_results.race_id)
      WHERE race_uuid IS NULL
    ''');

    // Populate race_uuid, runner_uuid, team_uuid for race_participants
    await db.rawUpdate('''
      UPDATE race_participants
      SET race_uuid = (SELECT uuid FROM races WHERE races.race_id = race_participants.race_id)
      WHERE race_uuid IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE race_participants
      SET runner_uuid = (SELECT uuid FROM runners WHERE runners.runner_id = race_participants.runner_id)
      WHERE runner_uuid IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE race_participants
      SET team_uuid = (SELECT uuid FROM teams WHERE teams.team_id = race_participants.team_id)
      WHERE team_uuid IS NULL
    ''');
  }

  // Placeholder: persist cursors in sync_state
  Future<void> setCursor(String key, String value) async {
    final db = await _db.database;
    await db.insert('sync_state', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCursor(String key) async {
    final db = await _db.database;
    final rows =
        await db.query('sync_state', where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty ? rows.first['value'] as String : null;
  }

  /// Fields excluded from conflict detection: sync metadata and local-only PKs/FKs
  /// that are not present on the remote row.
  static const _conflictExcludedFields = {
    'uuid',
    'updated_at',
    'created_at',
    'is_dirty',
    'deleted_at',
    'owner_user_id',
    // Local integer PKs / FKs — not synced as data columns
    'id',
    'runner_id',
    'team_id',
    'race_id',
  };

  /// Detect if there's an actual data conflict when timestamps are equal.
  ///
  /// Compares all data columns present in either row, automatically picking up
  /// any new columns added to synced tables without requiring code changes here.
  _DataConflictResult _detectDataConflict(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final differences = <String>[];

    final allKeys = {...local.keys, ...remote.keys}
        .difference(_conflictExcludedFields);

    for (final field in allKeys) {
      final localValue = local[field];
      final remoteValue = remote[field];

      // Handle null comparisons
      if (localValue == null && remoteValue == null) continue;
      if (localValue == null || remoteValue == null) {
        differences.add('$field: local=$localValue, remote=$remoteValue');
        continue;
      }

      // Handle different types that might represent the same value.
      // Fall back to numeric comparison so 3.0 and 3 are not treated as a conflict.
      final localStr = localValue.toString();
      final remoteStr = remoteValue.toString();
      if (localStr != remoteStr) {
        final localNum = num.tryParse(localStr);
        final remoteNum = num.tryParse(remoteStr);
        if (localNum == null || remoteNum == null || localNum != remoteNum) {
          differences.add('$field: local=$localValue, remote=$remoteValue');
        }
      }
    }

    return _DataConflictResult(differences.isNotEmpty, differences);
  }

  /// Pure in-memory conflict check — no network calls.
  /// [remoteData] is the already-fetched remote row, or null if none exists.
  _PushConflictResult _checkForPushConflictInMemory(
      Map<String, dynamic> localData, Map<String, dynamic>? remoteData) {
    if (remoteData == null) {
      return _PushConflictResult(false, {'reason': 'no_remote_data'});
    }

    final localUpdated =
        DateTime.tryParse(localData['updated_at']?.toString() ?? '');
    final remoteUpdated =
        DateTime.tryParse(remoteData['updated_at']?.toString() ?? '');

    if (localUpdated == null || remoteUpdated == null) {
      return _PushConflictResult(true, {
        'reason': 'timestamp_missing',
        'local_updated': localData['updated_at'],
        'remote_updated': remoteData['updated_at'],
      });
    }

    if (remoteUpdated.isAfter(localUpdated)) {
      final dataConflict = _detectDataConflict(localData, remoteData);
      return _PushConflictResult(true, {
        'reason': 'remote_newer',
        'time_diff_minutes': remoteUpdated.difference(localUpdated).inMinutes,
        'data_differences': dataConflict.differences,
      });
    }

    return _PushConflictResult(false, {'reason': 'local_newer_or_equal'});
  }

  // Public API

  @override
  Future<void> dispose() async {
    await _syncEventController.close();
  }

  @override
  Future<void> syncAll() async {
    try {
      await _remote.init();
      if (!_remote.isInitialized) {
        Logger.d('Remote not configured; skipping sync.');
        return;
      }

      // Auth guard: sync requires a signed-in user. Pull operations filter
      // remote rows by owner_user_id; without a user, the filter is omitted
      // and Supabase would return all publicly-visible rows (or silently fail
      // at RLS). Per-row RLS is a last line of defence, not a substitute for
      // this check.
      if (!_auth.isSignedIn) {
        Logger.d('Sync skipped: user is not authenticated.');
        return;
      }

      await ensureLocalUuids();
      await pullAll();
      await pushAll();
    } catch (e) {
      Logger.d('Sync error: $e');
      rethrow;
    }
  }

  // Push dirty rows
  Future<void> pushAll() async {
    // Auth guard: every pushed row must carry an owner_user_id. Check once
    // here rather than per-row to avoid unnecessary DB and network work before
    // discovering the user is unauthenticated.
    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('Push skipped: user is not authenticated.');
      return;
    }

    final db = await _db.database;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Push skipped: normalized schema not found yet.');
      return;
    }

    Future<void> pushTable(String table, String onConflict,
        {String? localPkColumn}) async {
      final rows = await db.query(table, where: 'is_dirty = 1');
      if (rows.isEmpty) return;

      // Collect all UUIDs upfront for a single batch conflict check query
      final uuids = rows.map((r) => r['uuid']).whereType<String>().toList();

      // Fetch all matching remote rows in one round-trip
      final remoteRows = await _syncClient.fetchByUuids(table, uuids);
      final remoteMap = <String, Map<String, dynamic>>{};
      for (final r in remoteRows) {
        final u = r['uuid'] as String?;
        if (u != null) remoteMap[u] = r;
      }

      final payload = <Map<String, dynamic>>[];

      for (final row in rows) {
        final copy = Map<String, dynamic>.from(row);
        copy.remove('is_dirty');
        if (localPkColumn != null) copy.remove(localPkColumn);
        // uid is guaranteed non-null by the guard at the top of pushAll().
        copy['owner_user_id'] = uid;
        // Older local rows may have NULL created_at if they pre-date the column.
        // Supabase enforces NOT NULL on created_at, so supply a fallback.
        copy['created_at'] ??= copy['updated_at'] ?? DateTime.now().toUtc().toIso8601String();

        // Resolve conflict in-memory against pre-fetched remote data
        final conflictCheck = _checkForPushConflictInMemory(
            copy, remoteMap[copy['uuid'] as String?]);
        if (conflictCheck.hasConflict) {
          Logger.d(
              '⚠️ Push conflict detected for $table UUID:${copy['uuid']}: ${conflictCheck.details} — skipping push, clearing dirty flag');
          // Remote is newer: clear the dirty flag without pushing so we don't
          // overwrite the more-recent remote data. The next pullAll will bring
          // the remote version down.
          final skippedUuid = copy['uuid'] as String?;
          if (skippedUuid != null) {
            await db.rawUpdate(
                'UPDATE $table SET is_dirty = 0 WHERE uuid = ?', [skippedUuid]);
          }
          continue;
        }

        payload.add(copy);
      }

      if (payload.isNotEmpty) {
        await _syncClient.upsertRows(table, payload, onConflict: onConflict);
        final pushedUuids =
            payload.map((r) => r['uuid']).whereType<String>().toList();
        if (pushedUuids.isNotEmpty) {
          final qMarks = List.filled(pushedUuids.length, '?').join(',');
          await db.rawUpdate(
              'UPDATE $table SET is_dirty = 0 WHERE uuid IN ($qMarks)',
              pushedUuids);
        }
        Logger.d('Pushed ${payload.length} dirty records for $table');
      }
    }

    await pushTable('runners', 'uuid', localPkColumn: 'runner_id');
    await pushTable('teams', 'uuid', localPkColumn: 'team_id');
    await pushTable('races', 'uuid', localPkColumn: 'race_id');
    await _pushRaceResults();
    await _pushRaceParticipants();
  }

  /// Push dirty race_results rows using UUID-based foreign keys.
  /// Strips local integer runner_id/race_id from the remote payload and
  /// requires runner_uuid/race_uuid to be present.
  Future<void> _pushRaceResults() async {
    final db = await _db.database;

    // Auth guard: defensive check in case _pushRaceResults is called outside
    // syncAll(). In the normal flow the top-level guard in syncAll() ensures
    // the user is authenticated before any push method is reached.
    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('Push skipped: user is not authenticated (race_results).');
      return;
    }

    final rows = await db.query('race_results', where: 'is_dirty = 1');
    if (rows.isEmpty) return;

    // Collect all UUIDs upfront for a single batch conflict check query
    final uuids = rows.map((r) => r['uuid']).whereType<String>().toList();

    // Fetch all matching remote rows in one round-trip
    final remoteRows = await _syncClient.fetchByUuids('race_results', uuids);
    final remoteMap = <String, Map<String, dynamic>>{};
    for (final r in remoteRows) {
      final u = r['uuid'] as String?;
      if (u != null) remoteMap[u] = r;
    }

    final payload = <Map<String, dynamic>>[];

    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('is_dirty');
      // Remove local integer PKs and FKs — remote schema uses UUIDs
      copy.remove('result_id');
      copy.remove('runner_id');
      copy.remove('race_id');

      final runnerUuid = copy['runner_uuid'];
      final raceUuid = copy['race_uuid'];
      if (runnerUuid == null || raceUuid == null) {
        Logger.d(
            'Skipping race_result UUID:${copy['uuid']} — missing runner_uuid or race_uuid');
        continue;
      }

      copy['owner_user_id'] = uid;
      copy['created_at'] ??= copy['updated_at'] ?? DateTime.now().toUtc().toIso8601String();

      // Resolve conflict in-memory against pre-fetched remote data
      final conflictCheck = _checkForPushConflictInMemory(
          copy, remoteMap[copy['uuid'] as String?]);
      if (conflictCheck.hasConflict) {
        Logger.d(
            '⚠️ Push conflict for race_results UUID:${copy['uuid']}: ${conflictCheck.details} — skipping push, clearing dirty flag');
        final skippedUuid = copy['uuid'] as String?;
        if (skippedUuid != null) {
          await db.rawUpdate(
              'UPDATE race_results SET is_dirty = 0 WHERE uuid = ?',
              [skippedUuid]);
        }
        continue;
      }

      payload.add(copy);
    }

    if (payload.isNotEmpty) {
      await _syncClient.upsertRows('race_results', payload, onConflict: 'uuid');
      final pushedUuids =
          payload.map((r) => r['uuid']).whereType<String>().toList();
      if (pushedUuids.isNotEmpty) {
        final qMarks = List.filled(pushedUuids.length, '?').join(',');
        await db.rawUpdate(
            'UPDATE race_results SET is_dirty = 0 WHERE uuid IN ($qMarks)',
            pushedUuids);
      }
      Logger.d('Pushed ${payload.length} dirty records for race_results');
    }
  }

  /// Push dirty race_participants rows using UUID-based foreign keys.
  /// Strips local integer race_id/runner_id/team_id from the remote payload and
  /// requires race_uuid/runner_uuid to be present.
  Future<void> _pushRaceParticipants() async {
    final db = await _db.database;

    // Auth guard: defensive check in case _pushRaceParticipants is called
    // outside syncAll(). In the normal flow the top-level guard in syncAll()
    // ensures the user is authenticated before any push method is reached.
    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('Push skipped: user is not authenticated (race_participants).');
      return;
    }

    final rows = await db.query('race_participants', where: 'is_dirty = 1');
    if (rows.isEmpty) return;

    final payload = <Map<String, dynamic>>[];

    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('is_dirty');
      // Remove local integer foreign keys — remote schema uses UUIDs
      copy.remove('race_id');
      copy.remove('runner_id');
      copy.remove('team_id');

      final raceUuid = copy['race_uuid'];
      final runnerUuid = copy['runner_uuid'];
      if (raceUuid == null || runnerUuid == null) {
        Logger.d(
            'Skipping race_participant — missing race_uuid or runner_uuid');
        continue;
      }

      copy['owner_user_id'] = uid;
      copy['created_at'] ??= copy['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
      payload.add(copy);
    }

    if (payload.isNotEmpty) {
      await _syncClient.upsertRows(
          'race_participants', payload,
          onConflict: 'race_uuid,runner_uuid');
      final pushedUuids =
          payload.map((r) => r['uuid']).whereType<String>().toList();
      if (pushedUuids.isNotEmpty) {
        final qMarks = List.filled(pushedUuids.length, '?').join(',');
        await db.rawUpdate(
          'UPDATE race_participants SET is_dirty = 0 WHERE uuid IN ($qMarks)',
          pushedUuids,
        );
      }
      Logger.d('Pushed ${payload.length} dirty records for race_participants');
    }
  }

  // Pull changed rows
  Future<void> pullAll() async {
    final db = await _db.database;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Pull skipped: normalized schema not found yet.');
      return;
    }

    final uid = _auth.currentUserId;
    final accessibleOwnerIds = uid != null
        ? await _syncClient.fetchAccessibleOwnerIds(uid)
        : <String>[];

    final changedTables = <String>{};
    final changedRaceIds = <int>{};

    Future<void> pullTable(String table) async {
      final cursorKey = 'cursor.$table';
      final cursor = await getCursor(cursorKey);
      final data = await _syncClient.fetchTableRows(
        table,
        accessibleOwnerIds,
        cursor: cursor,
      );

      // Batch-fetch all matching local rows in a single query to avoid
      // N per-row round-trips when the remote payload contains many rows.
      final remoteUuids =
          data.map((r) => r['uuid']).whereType<String>().toList();
      final localsByUuid = <String, Map<String, dynamic>>{};
      if (remoteUuids.isNotEmpty) {
        final qMarks = List.filled(remoteUuids.length, '?').join(',');
        final localRows = await db.rawQuery(
            'SELECT * FROM $table WHERE uuid IN ($qMarks)', remoteUuids);
        for (final r in localRows) {
          final u = r['uuid'] as String?;
          if (u != null) localsByUuid[u] = r;
        }
      }

      String? newCursor = cursor;
      bool hadWrites = false;
      for (final row in data) {
        final remote = Map<String, dynamic>.from(row);
        final uuid = remote['uuid'] as String?;
        if (uuid == null) continue;
        final locals = localsByUuid.containsKey(uuid)
            ? [localsByUuid[uuid]!]
            : <Map<String, dynamic>>[];
        // Remove remote-only fields not present locally
        remote.remove('owner_user_id');

        // Handle remote tombstones: apply soft delete regardless of LWW
        if (remote['deleted_at'] != null) {
          if (locals.isEmpty) {
            // Insert tombstone so it is not re-fetched on the next pull
            final insert = Map<String, dynamic>.from(remote);
            insert['is_dirty'] = 0;
            await db.insert(table, insert,
                conflictAlgorithm: ConflictAlgorithm.replace);
            hadWrites = true;
          } else if (locals.first['deleted_at'] == null) {
            // Active local row — apply the remote tombstone
            await db.update(
              table,
              {'deleted_at': remote['deleted_at'], 'is_dirty': 0},
              where: 'uuid = ?',
              whereArgs: [uuid],
            );
            Logger.d('Applied remote tombstone to $table UUID:$uuid');
            hadWrites = true;
          }
          final updatedAtStr = remote['updated_at']?.toString();
          if (updatedAtStr != null &&
              (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
            newCursor = updatedAtStr;
          }
          continue;
        }

        if (locals.isEmpty) {
          final insert = Map<String, dynamic>.from(remote);
          insert['is_dirty'] = 0;
          await db.insert(table, insert,
              conflictAlgorithm: ConflictAlgorithm.replace);
          hadWrites = true;
        } else {
          final local = locals.first;
          final localUpdated =
              DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
          final remoteUpdated =
              DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);

          // Determine which version to keep based on Last-Write-Wins
          bool shouldUpdateLocal = false;
          String conflictReason = '';

          if (remoteUpdated.isAfter(localUpdated)) {
            // Remote is newer - always update local
            shouldUpdateLocal = true;
            conflictReason = 'remote_newer';
          } else if (localUpdated.isAfter(remoteUpdated)) {
            // Local is newer - keep local, no action needed
            conflictReason = 'local_newer';
          } else {
            // Equal timestamps - compare data content to detect actual conflicts
            final dataConflict = _detectDataConflict(local, remote);
            if (dataConflict.hasConflict) {
              // Data is different despite same timestamp - this is a real conflict
              // Default to keeping remote (could be made configurable)
              shouldUpdateLocal = true;
              conflictReason = 'equal_timestamp_data_conflict';
              Logger.d(
                  '⚠️ Data conflict detected for $table UUID:$uuid - same timestamp but different data: ${dataConflict.differences}');
            } else {
              // Data is identical - no conflict
              conflictReason = 'no_conflict_identical_data';
            }
          }

          if (shouldUpdateLocal) {
            final update = Map<String, dynamic>.from(remote);
            // Remote won LWW — always clear the dirty flag so this row is not
            // re-pushed over the newer remote data on the next sync cycle.
            update['is_dirty'] = 0;

            await db
                .update(table, update, where: 'uuid = ?', whereArgs: [uuid]);
            Logger.d('Updated $table UUID:$uuid from remote ($conflictReason)');
            hadWrites = true;
          } else {
            Logger.d('Kept local $table UUID:$uuid ($conflictReason)');
          }
        }
        final updatedAtStr = remote['updated_at']?.toString();
        if (updatedAtStr != null &&
            (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
          newCursor = updatedAtStr;
        }
      }
      if (hadWrites) changedTables.add(table);
      if (newCursor != null && newCursor != cursor) {
        await setCursor(cursorKey, newCursor);
      }
    }

    await pullTable('runners');
    await pullTable('teams');
    await pullTable('races');
    await _pullRaceResults(accessibleOwnerIds, changedTables, changedRaceIds);
    await _pullRaceParticipants(accessibleOwnerIds, changedTables);

    if (changedTables.isNotEmpty) {
      _syncEventController.add(SyncEvent(
        timestamp: DateTime.now(),
        changedTables: changedTables,
        changedRaceIds: changedRaceIds,
      ));
    }
  }

  /// Pull race_results from remote and resolve UUID-based foreign keys to
  /// local integer IDs before inserting or updating. Skips any row whose
  /// runner_uuid or race_uuid cannot be resolved locally (will retry next sync).
  Future<void> _pullRaceResults(
      List<String> accessibleOwnerIds,
      Set<String> changedTables,
      Set<int> changedRaceIds) async {
    final db = await _db.database;

    const table = 'race_results';
    const cursorKey = 'cursor.$table';
    final cursor = await getCursor(cursorKey);

    final data = await _syncClient.fetchTableRows(
      table,
      accessibleOwnerIds,
      cursor: cursor,
    );
    if (data.isEmpty) return;

    // Batch-resolve all runner_uuids and race_uuids to local integer IDs
    final runnerUuids =
        data.map((r) => r['runner_uuid']).whereType<String>().toSet().toList();
    final raceUuids =
        data.map((r) => r['race_uuid']).whereType<String>().toSet().toList();

    final runnerUuidToId = <String, int>{};
    final raceUuidToId = <String, int>{};

    if (runnerUuids.isNotEmpty) {
      final qMarks = List.filled(runnerUuids.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT uuid, runner_id FROM runners WHERE uuid IN ($qMarks)',
          runnerUuids);
      for (final r in rows) {
        runnerUuidToId[r['uuid'] as String] = r['runner_id'] as int;
      }
    }
    if (raceUuids.isNotEmpty) {
      final qMarks = List.filled(raceUuids.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT uuid, race_id FROM races WHERE uuid IN ($qMarks)', raceUuids);
      for (final r in rows) {
        raceUuidToId[r['uuid'] as String] = r['race_id'] as int;
      }
    }

    // Batch-fetch all matching local rows in a single query.
    final resultUuids =
        data.map((r) => r['uuid']).whereType<String>().toList();
    final localsByUuid = <String, Map<String, dynamic>>{};
    if (resultUuids.isNotEmpty) {
      final qMarks = List.filled(resultUuids.length, '?').join(',');
      final localRows = await db.rawQuery(
          'SELECT * FROM $table WHERE uuid IN ($qMarks)', resultUuids);
      for (final r in localRows) {
        final u = r['uuid'] as String?;
        if (u != null) localsByUuid[u] = r;
      }
    }

    String? newCursor = cursor;
    bool hadWrites = false;

    for (final row in data) {
      final remote = Map<String, dynamic>.from(row);
      final uuid = remote['uuid'] as String?;
      if (uuid == null) continue;

      remote.remove('owner_user_id');
      // result_id on remote is a bigserial with its own sequence; strip it so
      // SQLite assigns a local AUTOINCREMENT ID instead of importing the remote one.
      remote.remove('result_id');

      final runnerUuid = remote['runner_uuid'] as String?;
      final raceUuid = remote['race_uuid'] as String?;

      if (runnerUuid == null || raceUuid == null) {
        Logger.d(
            'Skipping race_result UUID:$uuid — missing runner_uuid or race_uuid');
        continue;
      }

      final runnerId = runnerUuidToId[runnerUuid];
      final raceId = raceUuidToId[raceUuid];

      if (runnerId == null || raceId == null) {
        Logger.d(
            'Skipping race_result UUID:$uuid — runner_uuid=$runnerUuid or race_uuid=$raceUuid not available locally.');
        final skippedUpdatedAt = remote['updated_at']?.toString();
        if (skippedUpdatedAt != null &&
            (newCursor == null ||
                skippedUpdatedAt.compareTo(newCursor) > 0)) {
          newCursor = skippedUpdatedAt;
        }
        continue;
      }

      // Inject resolved local integer IDs
      remote['runner_id'] = runnerId;
      remote['race_id'] = raceId;

      final locals = localsByUuid.containsKey(uuid)
          ? [localsByUuid[uuid]!]
          : <Map<String, dynamic>>[];

      // Handle tombstones: apply soft delete regardless of LWW
      if (remote['deleted_at'] != null) {
        if (locals.isEmpty) {
          final insert = Map<String, dynamic>.from(remote);
          insert['is_dirty'] = 0;
          await db.insert(table, insert,
              conflictAlgorithm: ConflictAlgorithm.replace);
          hadWrites = true;
          changedRaceIds.add(raceId);
        } else if (locals.first['deleted_at'] == null) {
          await db.update(
            table,
            {'deleted_at': remote['deleted_at'], 'is_dirty': 0},
            where: 'uuid = ?',
            whereArgs: [uuid],
          );
          Logger.d('Applied remote tombstone to $table UUID:$uuid');
          hadWrites = true;
          changedRaceIds.add(raceId);
        }
        final updatedAtStr = remote['updated_at']?.toString();
        if (updatedAtStr != null &&
            (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
          newCursor = updatedAtStr;
        }
        continue;
      }

      if (locals.isEmpty) {
        final insert = Map<String, dynamic>.from(remote);
        insert['is_dirty'] = 0;
        await db.insert(table, insert,
            conflictAlgorithm: ConflictAlgorithm.replace);
        hadWrites = true;
        changedRaceIds.add(raceId);
      } else {
        final local = locals.first;
        final localUpdated =
            DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final remoteUpdated =
            DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);

        bool shouldUpdateLocal = false;
        String conflictReason = '';

        if (remoteUpdated.isAfter(localUpdated)) {
          shouldUpdateLocal = true;
          conflictReason = 'remote_newer';
        } else if (localUpdated.isAfter(remoteUpdated)) {
          conflictReason = 'local_newer';
        } else {
          final dataConflict = _detectDataConflict(local, remote);
          if (dataConflict.hasConflict) {
            shouldUpdateLocal = true;
            conflictReason = 'equal_timestamp_data_conflict';
            Logger.d(
                '⚠️ Data conflict for $table UUID:$uuid — same timestamp but different data: ${dataConflict.differences}');
          } else {
            conflictReason = 'no_conflict_identical_data';
          }
        }

        if (shouldUpdateLocal) {
          final update = Map<String, dynamic>.from(remote);
          update['is_dirty'] = 0;
          await db.update(table, update, where: 'uuid = ?', whereArgs: [uuid]);
          Logger.d('Updated $table UUID:$uuid from remote ($conflictReason)');
          hadWrites = true;
          changedRaceIds.add(raceId);
        } else {
          Logger.d('Kept local $table UUID:$uuid ($conflictReason)');
        }
      }

      final updatedAtStr = remote['updated_at']?.toString();
      if (updatedAtStr != null &&
          (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
        newCursor = updatedAtStr;
      }
    }

    if (hadWrites) changedTables.add(table);
    if (newCursor != null && newCursor != cursor) {
      await setCursor(cursorKey, newCursor);
    }
  }

  /// Pull race_participants from remote and resolve UUID-based foreign keys to
  /// local integer IDs before inserting or updating. Skips rows where any UUID
  /// cannot be resolved locally (will retry next sync).
  Future<void> _pullRaceParticipants(
      List<String> accessibleOwnerIds, Set<String> changedTables) async {
    final db = await _db.database;

    const table = 'race_participants';
    const cursorKey = cursorRaceParticipants;
    final cursor = await getCursor(cursorKey);

    final data = await _syncClient.fetchTableRows(
      table,
      accessibleOwnerIds,
      cursor: cursor,
    );
    if (data.isEmpty) return;

    // Batch-resolve all UUIDs to local integer IDs
    final raceUuids =
        data.map((r) => r['race_uuid']).whereType<String>().toSet().toList();
    final runnerUuids =
        data.map((r) => r['runner_uuid']).whereType<String>().toSet().toList();
    final teamUuids =
        data.map((r) => r['team_uuid']).whereType<String>().toSet().toList();

    final raceUuidToId = <String, int>{};
    final runnerUuidToId = <String, int>{};
    final teamUuidToId = <String, int>{};

    if (raceUuids.isNotEmpty) {
      final qMarks = List.filled(raceUuids.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT uuid, race_id FROM races WHERE uuid IN ($qMarks)', raceUuids);
      for (final r in rows) {
        raceUuidToId[r['uuid'] as String] = r['race_id'] as int;
      }
    }
    if (runnerUuids.isNotEmpty) {
      final qMarks = List.filled(runnerUuids.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT uuid, runner_id FROM runners WHERE uuid IN ($qMarks)',
          runnerUuids);
      for (final r in rows) {
        runnerUuidToId[r['uuid'] as String] = r['runner_id'] as int;
      }
    }
    if (teamUuids.isNotEmpty) {
      final qMarks = List.filled(teamUuids.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT uuid, team_id FROM teams WHERE uuid IN ($qMarks)', teamUuids);
      for (final r in rows) {
        teamUuidToId[r['uuid'] as String] = r['team_id'] as int;
      }
    }

    // Batch-fetch all matching local race_participant rows by UUID in a single
    // query to avoid N per-row round-trips.
    final participantUuids =
        data.map((r) => r['uuid']).whereType<String>().toList();
    final localsByUuid = <String, Map<String, dynamic>>{};
    if (participantUuids.isNotEmpty) {
      final qMarks = List.filled(participantUuids.length, '?').join(',');
      final localRows = await db.rawQuery(
          'SELECT * FROM $table WHERE uuid IN ($qMarks)', participantUuids);
      for (final r in localRows) {
        final u = r['uuid'] as String?;
        if (u != null) localsByUuid[u] = r;
      }
    }

    String? newCursor = cursor;
    bool hadWrites = false;

    for (final row in data) {
      final remote = Map<String, dynamic>.from(row);
      remote.remove('owner_user_id');

      final uuid = remote['uuid'] as String?;
      final raceUuid = remote['race_uuid'] as String?;
      final runnerUuid = remote['runner_uuid'] as String?;
      final teamUuid = remote['team_uuid'] as String?;

      if (raceUuid == null || runnerUuid == null) {
        Logger.d(
            'Skipping race_participant — missing race_uuid or runner_uuid');
        continue;
      }

      final raceId = raceUuidToId[raceUuid];
      final runnerId = runnerUuidToId[runnerUuid];

      if (raceId == null || runnerId == null) {
        Logger.d(
            'Skipping race_participant race_uuid=$raceUuid runner_uuid=$runnerUuid — parent race or runner not available locally.');
        final skippedUpdatedAt = remote['updated_at']?.toString();
        if (skippedUpdatedAt != null &&
            (newCursor == null ||
                skippedUpdatedAt.compareTo(newCursor) > 0)) {
          newCursor = skippedUpdatedAt;
        }
        continue;
      }

      final teamId = teamUuid != null ? teamUuidToId[teamUuid] : null;

      // Inject resolved local integer IDs
      remote['race_id'] = raceId;
      remote['runner_id'] = runnerId;
      if (teamId != null) remote['team_id'] = teamId;

      final locals = uuid != null && localsByUuid.containsKey(uuid)
          ? [localsByUuid[uuid]!]
          : <Map<String, dynamic>>[];

      // Handle tombstones
      if (remote['deleted_at'] != null) {
        if (locals.isEmpty) {
          final insert = Map<String, dynamic>.from(remote);
          insert['is_dirty'] = 0;
          await db.insert(table, insert,
              conflictAlgorithm: ConflictAlgorithm.replace);
          hadWrites = true;
        } else if (locals.first['deleted_at'] == null) {
          await db.update(
            table,
            {'deleted_at': remote['deleted_at'], 'is_dirty': 0},
            where: 'uuid = ?',
            whereArgs: [uuid],
          );
          Logger.d(
              'Applied remote tombstone to $table race_uuid=$raceUuid runner_uuid=$runnerUuid');
          hadWrites = true;
        }
        final updatedAtStr = remote['updated_at']?.toString();
        if (updatedAtStr != null &&
            (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
          newCursor = updatedAtStr;
        }
        continue;
      }

      if (locals.isEmpty) {
        final insert = Map<String, dynamic>.from(remote);
        insert['is_dirty'] = 0;
        await db.insert(table, insert,
            conflictAlgorithm: ConflictAlgorithm.replace);
        hadWrites = true;
      } else {
        final local = locals.first;
        final localUpdated =
            DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final remoteUpdated =
            DateTime.tryParse(remote['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);

        bool shouldUpdateLocal = false;
        String conflictReason = '';

        if (remoteUpdated.isAfter(localUpdated)) {
          shouldUpdateLocal = true;
          conflictReason = 'remote_newer';
        } else if (localUpdated.isAfter(remoteUpdated)) {
          conflictReason = 'local_newer';
        } else {
          conflictReason = 'no_conflict_identical_data';
        }

        if (shouldUpdateLocal) {
          final update = Map<String, dynamic>.from(remote);
          update['is_dirty'] = 0;
          await db.update(table, update,
              where: 'uuid = ?', whereArgs: [uuid]);
          Logger.d(
              'Updated $table race_uuid=$raceUuid runner_uuid=$runnerUuid from remote ($conflictReason)');
          hadWrites = true;
        } else {
          Logger.d(
              'Kept local $table race_uuid=$raceUuid runner_uuid=$runnerUuid ($conflictReason)');
        }
      }

      final updatedAtStr = remote['updated_at']?.toString();
      if (updatedAtStr != null &&
          (newCursor == null || updatedAtStr.compareTo(newCursor) > 0)) {
        newCursor = updatedAtStr;
      }
    }

    if (hadWrites) changedTables.add(table);
    if (newCursor != null && newCursor != cursor) {
      await setCursor(cursorKey, newCursor);
    }
  }
}
