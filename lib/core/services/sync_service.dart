import 'dart:async';

import 'package:uuid/uuid.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/services/remote_api_client.dart';
import 'package:xceleration/core/services/auth_service.dart';

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
///
/// Usage:
/// ```dart
/// // Sync is disabled by default - requires user authentication
///
/// // Enable authenticated sync after user signs in
/// await SyncService.instance.setSyncMode(SyncService.syncModeAuthenticated);
/// await SyncService.instance.syncAll(); // Now works!
///
/// // Check current mode (defaults to 'off')
/// final mode = await SyncService.instance.getSyncMode();
/// print('Current sync mode: $mode'); // Will show 'off' or 'authenticated'
///
/// // Disable sync entirely
/// await SyncService.instance.setSyncMode(SyncService.syncModeOff);
///
/// // Manual override for testing/debugging
/// await SyncService.instance.forceEnableSyncForTesting();
/// ```
class SyncService {
  /// Sync mode preference
  static const String syncModeKey = 'sync_mode';
  static const String syncModeAuthenticated = 'authenticated';
  static const String syncModeOff = 'off';
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

  /// Check for potential conflicts before pushing data to remote
  Future<_PushConflictResult> _checkForPushConflict(
      String table, Map<String, dynamic> localData) async {
    try {
      final uuid = localData['uuid'];
      if (uuid == null) {
        return _PushConflictResult(false, {'reason': 'no_uuid'});
      }

      // Query remote for existing data
      final remoteData = await RemoteApiClient.instance.client
          .from(table)
          .select()
          .eq('uuid', uuid)
          .maybeSingle();

      if (remoteData == null) {
        // No remote data exists - no conflict
        return _PushConflictResult(false, {'reason': 'no_remote_data'});
      }

      // Compare timestamps
      final localUpdated =
          DateTime.tryParse(localData['updated_at']?.toString() ?? '');
      final remoteUpdated =
          DateTime.tryParse(remoteData['updated_at']?.toString() ?? '');

      if (localUpdated == null || remoteUpdated == null) {
        return _PushConflictResult(true, {
          'reason': 'timestamp_missing',
          'local_updated': localData['updated_at'],
          'remote_updated': remoteData['updated_at']
        });
      }

      if (remoteUpdated.isAfter(localUpdated)) {
        // Remote is newer - this is a conflict
        final dataConflict = _detectDataConflict(localData, remoteData);
        return _PushConflictResult(true, {
          'reason': 'remote_newer',
          'time_diff_minutes': remoteUpdated.difference(localUpdated).inMinutes,
          'data_differences': dataConflict.differences
        });
      }

      // Local is newer or same - no conflict
      return _PushConflictResult(false, {'reason': 'local_newer_or_equal'});
    } catch (e) {
      Logger.d('Error checking push conflict for $table: $e');
      return _PushConflictResult(
          false, {'reason': 'error', 'error': e.toString()});
    }
  }

  /// Get current sync mode preference
  Future<String> getSyncMode() async {
    final db = await DatabaseHelper.instance.databaseConn;
    final rows = await db
        .query('sync_state', where: 'key = ?', whereArgs: [syncModeKey]);
    final mode = rows.isNotEmpty ? rows.first['value'] as String : syncModeOff;
    Logger.d('Current sync mode: $mode (rows found: ${rows.length})');
    return mode;
  }

  /// Set sync mode preference
  Future<void> setSyncMode(String mode) async {
    final db = await DatabaseHelper.instance.databaseConn;
    await db.insert('sync_state', {'key': syncModeKey, 'value': mode},
        conflictAlgorithm: ConflictAlgorithm.replace);

    Logger.d('Sync mode set to: $mode');
  }

  /// Force enable sync for testing (bypasses authentication requirement)
  /// WARNING: Only use for testing/debugging!
  Future<void> forceEnableSyncForTesting() async {
    Logger.d('⚠️ Force enabling sync for testing (bypassing auth)');
    await setSyncMode(syncModeAuthenticated);
  }

  // Public API
  Future<void> syncAll() async {
    try {
      await RemoteApiClient.instance.init();
      if (!RemoteApiClient.instance.isInitialized) {
        Logger.d('Remote not configured; skipping sync.');
        return;
      }

      final syncMode = await getSyncMode();

      if (syncMode == syncModeOff) {
        Logger.d('Sync is disabled by user preference.');
        return;
      }

      // Require user to be signed in for sync (unless in testing mode)
      final isTestingMode =
          syncMode == 'authenticated' && !AuthService.instance.isSignedIn;
      if (!AuthService.instance.isSignedIn && !isTestingMode) {
        Logger.d('User not signed in; skipping sync.');
        return;
      }

      if (isTestingMode) {
        Logger.d('⚠️ Running in testing mode (authentication bypassed)');
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

      final payload = <Map<String, dynamic>>[];
      final conflictChecks = <Map<String, dynamic>>[];

      for (final row in rows) {
        final copy = Map<String, dynamic>.from(row);
        copy.remove('is_dirty');
        final uid = AuthService.instance.currentUserId;
        if (uid != null) {
          copy['owner_user_id'] = uid;
        } else {
          // Testing mode: use a dummy user ID
          copy['owner_user_id'] = 'test-user-id';
          Logger.d('⚠️ Using test user ID for push operation');
        }

        // Check for potential conflicts before pushing
        final conflictCheck = await _checkForPushConflict(table, copy);
        if (conflictCheck.hasConflict) {
          Logger.d(
              '⚠️ Push conflict detected for $table UUID:${copy['uuid']}: ${conflictCheck.details}');
          // For now, still push but log the conflict
          // In the future, you could implement conflict resolution UI here
        }

        payload.add(copy);
        conflictChecks.add(conflictCheck.details);
      }

      if (payload.isNotEmpty) {
        await client.from(table).upsert(payload, onConflict: onConflict);
        final uuids =
            payload.map((r) => r['uuid']).whereType<String>().toList();
        if (uuids.isNotEmpty) {
          final qMarks = List.filled(uuids.length, '?').join(',');
          await db.rawUpdate(
              'UPDATE $table SET is_dirty = 0 WHERE uuid IN ($qMarks)', uuids);
        }
        Logger.d('Pushed ${payload.length} dirty records for $table');
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
      final uid = AuthService.instance.currentUserId ??
          'test-user-id'; // Fallback for testing
      if (uid == 'test-user-id') {
        Logger.d('⚠️ Using test user ID for pull operation');
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
