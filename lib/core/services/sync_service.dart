import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';

/// Emitted by [SyncService.syncEvents] after each successful [SyncService.pullAll].
class SyncEvent {
  const SyncEvent({required this.timestamp, required this.changedTables});

  /// When the pull completed.
  final DateTime timestamp;

  /// Tables that had at least one row inserted or updated during this pull.
  final Set<String> changedTables;
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
  /// Sync mode preference
  static const String syncModeKey = 'sync_mode';
  static const String syncModeAuthenticated = 'authenticated';
  static const String syncModeOff = 'off';

  final IDatabaseHelper _db;
  final IRemoteApiClient _remote;
  final IAuthService _auth;

  SyncService({
    required IDatabaseHelper db,
    required IRemoteApiClient remote,
    required IAuthService auth,
  })  : _db = db,
        _remote = remote,
        _auth = auth;

  final _syncEventController = StreamController<SyncEvent>.broadcast();

  /// Emits a [SyncEvent] after each successful [pullAll] that wrote at least one row.
  @override
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

  final _uuid = const Uuid();

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
    final db = await _db.databaseConn;
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
    final db = await _db.databaseConn;
    await db.insert('sync_state', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getCursor(String key) async {
    final db = await _db.databaseConn;
    final rows =
        await db.query('sync_state', where: 'key = ?', whereArgs: [key]);
    return rows.isNotEmpty ? rows.first['value'] as String : null;
  }

  /// Detect if there's an actual data conflict when timestamps are equal
  _DataConflictResult _detectDataConflict(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final differences = <String>[];

    // Define fields that should be compared for conflicts (exclude metadata fields)
    final fieldsToCompare = [
      'name',
      'bib_number',
      'grade',
      'abbreviation',
      'color',
      'race_date',
      'location',
      'distance',
      'distance_unit',
      'flow_state',
      'place',
      'finish_time'
    ];

    for (final field in fieldsToCompare) {
      final localValue = local[field];
      final remoteValue = remote[field];

      // Handle null comparisons
      if (localValue == null && remoteValue == null) continue;
      if (localValue == null || remoteValue == null) {
        differences.add('$field: local=$localValue, remote=$remoteValue');
        continue;
      }

      // Handle different types that might represent the same value
      if (localValue.toString() != remoteValue.toString()) {
        differences.add('$field: local=$localValue, remote=$remoteValue');
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

  /// Get current sync mode preference
  @override
  Future<String> getSyncMode() async {
    final db = await _db.databaseConn;
    final rows = await db
        .query('sync_state', where: 'key = ?', whereArgs: [syncModeKey]);
    final mode = rows.isNotEmpty ? rows.first['value'] as String : syncModeOff;
    Logger.d('Current sync mode: $mode (rows found: ${rows.length})');
    return mode;
  }

  /// Set sync mode preference
  @override
  Future<void> setSyncMode(String mode) async {
    final db = await _db.databaseConn;
    await db.insert('sync_state', {'key': syncModeKey, 'value': mode},
        conflictAlgorithm: ConflictAlgorithm.replace);

    Logger.d('Sync mode set to: $mode');
  }

  // Public API
  @override
  Future<void> syncAll() async {
    try {
      await _remote.init();
      if (!_remote.isInitialized) {
        Logger.d('Remote not configured; skipping sync.');
        return;
      }

      final syncMode = await getSyncMode();

      if (syncMode == syncModeOff) {
        Logger.d('Sync is disabled by user preference.');
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
    final client = _remote.client;
    final db = await _db.databaseConn;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Push skipped: normalized schema not found yet.');
      return;
    }

    Future<void> pushTable(String table, String onConflict) async {
      final rows = await db.query(table, where: 'is_dirty = 1');
      if (rows.isEmpty) return;

      // Collect all UUIDs upfront for a single batch conflict check query
      final uuids = rows.map((r) => r['uuid']).whereType<String>().toList();

      // Fetch all matching remote rows in one round-trip
      final remoteMap = <String, Map<String, dynamic>>{};
      if (uuids.isNotEmpty) {
        final remoteRows = await client
            .from(table)
            .select()
            .inFilter('uuid', uuids);
        for (final r in remoteRows) {
          final m = Map<String, dynamic>.from(r as Map);
          final u = m['uuid'] as String?;
          if (u != null) remoteMap[u] = m;
        }
      }

      final payload = <Map<String, dynamic>>[];

      for (final row in rows) {
        final copy = Map<String, dynamic>.from(row);
        copy.remove('is_dirty');
        final uid = _auth.currentUserId;
        if (uid != null) {
          copy['owner_user_id'] = uid;
        } else {
          Logger.d('User not authenticated; skipping push for $table');
          return;
        }

        // Resolve conflict in-memory against pre-fetched remote data
        final conflictCheck = _checkForPushConflictInMemory(
            copy, remoteMap[copy['uuid'] as String?]);
        if (conflictCheck.hasConflict) {
          Logger.d(
              '⚠️ Push conflict detected for $table UUID:${copy['uuid']}: ${conflictCheck.details}');
        }

        payload.add(copy);
      }

      if (payload.isNotEmpty) {
        await client.from(table).upsert(payload, onConflict: onConflict);
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

    await pushTable('runners', 'uuid');
    await pushTable('teams', 'uuid');
    await pushTable('races', 'uuid');
    await _pushRaceResults();
    await _pushRaceParticipants();
  }

  /// Push dirty race_results rows using UUID-based foreign keys.
  /// Strips local integer runner_id/race_id from the remote payload and
  /// requires runner_uuid/race_uuid to be present.
  Future<void> _pushRaceResults() async {
    final client = _remote.client;
    final db = await _db.databaseConn;

    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('User not authenticated; skipping push for race_results');
      return;
    }

    final rows = await db.query('race_results', where: 'is_dirty = 1');
    if (rows.isEmpty) return;

    // Collect all UUIDs upfront for a single batch conflict check query
    final uuids = rows.map((r) => r['uuid']).whereType<String>().toList();

    // Fetch all matching remote rows in one round-trip
    final remoteMap = <String, Map<String, dynamic>>{};
    if (uuids.isNotEmpty) {
      final remoteRows = await client
          .from('race_results')
          .select()
          .inFilter('uuid', uuids);
      for (final r in remoteRows) {
        final m = Map<String, dynamic>.from(r as Map);
        final u = m['uuid'] as String?;
        if (u != null) remoteMap[u] = m;
      }
    }

    final payload = <Map<String, dynamic>>[];

    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('is_dirty');
      // Remove local integer foreign keys — remote schema uses UUIDs
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

      // Resolve conflict in-memory against pre-fetched remote data
      final conflictCheck = _checkForPushConflictInMemory(
          copy, remoteMap[copy['uuid'] as String?]);
      if (conflictCheck.hasConflict) {
        Logger.d(
            '⚠️ Push conflict for race_results UUID:${copy['uuid']}: ${conflictCheck.details}');
      }

      payload.add(copy);
    }

    if (payload.isNotEmpty) {
      await client.from('race_results').upsert(payload, onConflict: 'uuid');
      final uuids =
          payload.map((r) => r['uuid']).whereType<String>().toList();
      if (uuids.isNotEmpty) {
        final qMarks = List.filled(uuids.length, '?').join(',');
        await db.rawUpdate(
            'UPDATE race_results SET is_dirty = 0 WHERE uuid IN ($qMarks)',
            uuids);
      }
      Logger.d('Pushed ${payload.length} dirty records for race_results');
    }
  }

  /// Push dirty race_participants rows using UUID-based foreign keys.
  /// Strips local integer race_id/runner_id/team_id from the remote payload and
  /// requires race_uuid/runner_uuid to be present.
  Future<void> _pushRaceParticipants() async {
    final client = _remote.client;
    final db = await _db.databaseConn;

    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('User not authenticated; skipping push for race_participants');
      return;
    }

    final rows = await db.query('race_participants', where: 'is_dirty = 1');
    if (rows.isEmpty) return;

    final payload = <Map<String, dynamic>>[];
    final pushedKeys = <(String, String)>[];

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
      payload.add(copy);
      pushedKeys.add((raceUuid as String, runnerUuid as String));
    }

    if (payload.isNotEmpty) {
      await client
          .from('race_participants')
          .upsert(payload, onConflict: 'race_uuid,runner_uuid');
      for (final (raceUuid, runnerUuid) in pushedKeys) {
        await db.rawUpdate(
          'UPDATE race_participants SET is_dirty = 0 WHERE race_uuid = ? AND runner_uuid = ?',
          [raceUuid, runnerUuid],
        );
      }
      Logger.d('Pushed ${payload.length} dirty records for race_participants');
    }
  }

  /// Returns the list of owner user IDs the current user can read:
  /// themselves plus any coaches who have shared access.
  Future<List<String>> _getAccessibleOwnerIds() async {
    final client = _remote.client;
    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('User not authenticated; cannot determine accessible owners');
      return [];
    }
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

  // Pull changed rows (scaffold only)
  Future<void> pullAll() async {
    final client = _remote.client;
    final db = await _db.databaseConn;
    if (!await _hasNormalizedSchema(db)) {
      Logger.d('Pull skipped: normalized schema not found yet.');
      return;
    }

    final accessibleOwnerIds = await _getAccessibleOwnerIds();
    final changedTables = <String>{};

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
      bool hadWrites = false;
      for (final row in data) {
        final remote = Map<String, dynamic>.from(row as Map);
        final uuid = remote['uuid'] as String?;
        if (uuid == null) continue;
        final locals =
            await db.query(table, where: 'uuid = ?', whereArgs: [uuid]);
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

            // Preserve local dirty flag if local has unsaved changes and remote is not significantly newer
            final localDirty = local['is_dirty'] == 1;
            final timeDifference = remoteUpdated.difference(localUpdated);
            if (localDirty && timeDifference.inMinutes < 5) {
              // Keep local dirty flag if changes were recent and local is dirty
              update['is_dirty'] = 1;
              Logger.d(
                  'Preserving dirty flag for $table UUID:$uuid - local has recent unsaved changes');
            } else {
              update['is_dirty'] = 0;
            }

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

    await pullTable('runners', 'runner_id');
    await pullTable('teams', 'team_id');
    await pullTable('races', 'race_id');
    await _pullRaceResults(accessibleOwnerIds, changedTables);
    await _pullRaceParticipants(accessibleOwnerIds, changedTables);

    if (changedTables.isNotEmpty) {
      _syncEventController.add(SyncEvent(
        timestamp: DateTime.now(),
        changedTables: changedTables,
      ));
    }
  }

  /// Pull race_results from remote and resolve UUID-based foreign keys to
  /// local integer IDs before inserting or updating. Skips any row whose
  /// runner_uuid or race_uuid cannot be resolved locally (will retry next sync).
  Future<void> _pullRaceResults(List<String> accessibleOwnerIds, Set<String> changedTables) async {
    final client = _remote.client;
    final db = await _db.databaseConn;

    const table = 'race_results';
    const cursorKey = 'cursor.$table';
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
    if (data.isEmpty) return;

    // Batch-resolve all runner_uuids and race_uuids to local integer IDs
    final runnerUuids =
        data.map((r) => (r as Map)['runner_uuid']).whereType<String>().toSet().toList();
    final raceUuids =
        data.map((r) => (r as Map)['race_uuid']).whereType<String>().toSet().toList();

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

    String? newCursor = cursor;
    bool hadWrites = false;

    for (final row in data) {
      final remote = Map<String, dynamic>.from(row as Map);
      final uuid = remote['uuid'] as String?;
      if (uuid == null) continue;

      remote.remove('owner_user_id');

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
            'Skipping race_result UUID:$uuid — runner_uuid=$runnerUuid or race_uuid=$raceUuid not yet pulled locally. Will retry on next sync.');
        continue;
      }

      // Inject resolved local integer IDs
      remote['runner_id'] = runnerId;
      remote['race_id'] = raceId;

      final locals =
          await db.query(table, where: 'uuid = ?', whereArgs: [uuid]);

      // Handle tombstones: apply soft delete regardless of LWW
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
          final localDirty = local['is_dirty'] == 1;
          final timeDifference = remoteUpdated.difference(localUpdated);
          if (localDirty && timeDifference.inMinutes < 5) {
            update['is_dirty'] = 1;
            Logger.d(
                'Preserving dirty flag for $table UUID:$uuid — local has recent unsaved changes');
          } else {
            update['is_dirty'] = 0;
          }
          await db.update(table, update, where: 'uuid = ?', whereArgs: [uuid]);
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

  /// Pull race_participants from remote and resolve UUID-based foreign keys to
  /// local integer IDs before inserting or updating. Skips rows where any UUID
  /// cannot be resolved locally (will retry next sync).
  Future<void> _pullRaceParticipants(List<String> accessibleOwnerIds, Set<String> changedTables) async {
    final client = _remote.client;
    final db = await _db.databaseConn;

    const table = 'race_participants';
    const cursorKey = cursorRaceParticipants;
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
    if (data.isEmpty) return;

    // Batch-resolve all UUIDs to local integer IDs
    final raceUuids =
        data.map((r) => (r as Map)['race_uuid']).whereType<String>().toSet().toList();
    final runnerUuids =
        data.map((r) => (r as Map)['runner_uuid']).whereType<String>().toSet().toList();
    final teamUuids =
        data.map((r) => (r as Map)['team_uuid']).whereType<String>().toSet().toList();

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

    String? newCursor = cursor;
    bool hadWrites = false;

    for (final row in data) {
      final remote = Map<String, dynamic>.from(row as Map);
      remote.remove('owner_user_id');

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
            'Skipping race_participant race_uuid=$raceUuid runner_uuid=$runnerUuid — not yet pulled locally. Will retry on next sync.');
        continue;
      }

      final teamId = teamUuid != null ? teamUuidToId[teamUuid] : null;

      // Inject resolved local integer IDs
      remote['race_id'] = raceId;
      remote['runner_id'] = runnerId;
      if (teamId != null) remote['team_id'] = teamId;

      final locals = await db.query(
        table,
        where: 'race_id = ? AND runner_id = ?',
        whereArgs: [raceId, runnerId],
      );

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
            where: 'race_id = ? AND runner_id = ?',
            whereArgs: [raceId, runnerId],
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
          final localDirty = local['is_dirty'] == 1;
          final timeDifference = remoteUpdated.difference(localUpdated);
          if (localDirty && timeDifference.inMinutes < 5) {
            update['is_dirty'] = 1;
          } else {
            update['is_dirty'] = 0;
          }
          await db.update(table, update,
              where: 'race_id = ? AND runner_id = ?',
              whereArgs: [raceId, runnerId]);
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
