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

/// Tracks how far a pull may advance its cursor.
///
/// Pulls request rows with `updated_at > cursor`, oldest first. When a row is
/// skipped because its parent race/runner isn't local yet, the cursor must
/// stay strictly before that row so it is fetched again on the next pull,
/// even if later rows in the batch are applied. If earlier rows share the
/// skipped row's timestamp, the cursor falls back to before that group.
class _PullCursor {
  _PullCursor(String? start) : _value = start;

  String? _value;
  String? _beforeCurrentGroup;
  bool _held = false;

  String? get value => _value;

  /// Whether [candidate] is a later moment than [current].
  ///
  /// Compared as times, not as text. The same moment can be written more than
  /// one way — a trailing 'Z' against '+00:00', with or without fractional
  /// seconds — and text order disagrees with time order on those: '.' sorts
  /// before 'Z'. A cursor that then refuses to move re-fetches the same rows
  /// on every sync, and [holdBefore] matching the stored value can miss, which
  /// leaves a row held for retry behind a cursor that has already passed it.
  static bool isLater(String candidate, String current) {
    final a = DateTime.tryParse(candidate);
    final b = DateTime.tryParse(current);
    if (a == null || b == null) return candidate.compareTo(current) > 0;
    return a.isAfter(b);
  }

  /// Call for every row that was applied or can safely be passed over.
  void advance(String? updatedAt) {
    if (_held || updatedAt == null) return;
    if (_value != null && !isLater(updatedAt, _value!)) return;
    _beforeCurrentGroup = _value;
    _value = updatedAt;
  }

  /// Call for a row that must be fetched again later.
  void holdBefore(String? updatedAt) {
    if (_held) return;
    _held = true;
    if (updatedAt != null && _value == updatedAt) {
      _value = _beforeCurrentGroup;
    }
  }
}

/// One parent a bridge row points at: the column naming it by uuid, the local
/// integer column, and where the uuid is looked up.
class _BridgeParent {
  const _BridgeParent({
    required this.uuidColumn,
    required this.idColumn,
    required this.parentTable,
    required this.parentIdColumn,
  });

  final String uuidColumn;
  final String idColumn;
  final String parentTable;
  final String parentIdColumn;
}

/// A join table whose identity is the pair of parents it links: `(race_id,
/// runner_id)` locally and `(race_uuid, runner_uuid)` on the server, the
/// primary key at both ends.
class _BridgeTable {
  const _BridgeTable({
    required this.table,
    required this.keyParents,
    this.otherParents = const [],
  });

  final String table;

  /// The parents that identify a row.
  final List<_BridgeParent> keyParents;

  /// Parents a row also points at without being identified by them. Their
  /// local columns are NOT NULL, so a new row cannot be written until they
  /// resolve.
  final List<_BridgeParent> otherParents;

  List<_BridgeParent> get allParents => [...keyParents, ...otherParents];

  String get cursorKey => 'cursor.$table';

  /// What an upsert of this table deduplicates on.
  String get conflictTarget => keyParents.map((p) => p.uuidColumn).join(',');

  String get keyColumns => keyParents.map((p) => p.uuidColumn).join(' and ');

  String get keyWhereClause =>
      '(${keyParents.map((p) => '${p.idColumn} = ?').join(' AND ')})';

  String keyOf(List<Object?> ids) => ids.join(':');
}

const _raceParticipants = _BridgeTable(
  table: 'race_participants',
  keyParents: [
    _BridgeParent(
        uuidColumn: 'race_uuid',
        idColumn: 'race_id',
        parentTable: 'races',
        parentIdColumn: 'race_id'),
    _BridgeParent(
        uuidColumn: 'runner_uuid',
        idColumn: 'runner_id',
        parentTable: 'runners',
        parentIdColumn: 'runner_id'),
  ],
  otherParents: [
    _BridgeParent(
        uuidColumn: 'team_uuid',
        idColumn: 'team_id',
        parentTable: 'teams',
        parentIdColumn: 'team_id'),
  ],
);

const _teamRosters = _BridgeTable(
  table: 'team_rosters',
  keyParents: [
    _BridgeParent(
        uuidColumn: 'team_uuid',
        idColumn: 'team_id',
        parentTable: 'teams',
        parentIdColumn: 'team_id'),
    _BridgeParent(
        uuidColumn: 'runner_uuid',
        idColumn: 'runner_id',
        parentTable: 'runners',
        parentIdColumn: 'runner_id'),
  ],
);

const _raceTeamParticipation = _BridgeTable(
  table: 'race_team_participation',
  keyParents: [
    _BridgeParent(
        uuidColumn: 'race_uuid',
        idColumn: 'race_id',
        parentTable: 'races',
        parentIdColumn: 'race_id'),
    _BridgeParent(
        uuidColumn: 'team_uuid',
        idColumn: 'team_id',
        parentTable: 'teams',
        parentIdColumn: 'team_id'),
  ],
);

/// Every join table that syncs, in the order a pull has to apply them.
const _bridgeTables = [_teamRosters, _raceTeamParticipation, _raceParticipants];

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
  static const String cursorTeamRosters = 'cursor.team_rosters';
  static const String cursorRaceTeamParticipation =
      'cursor.race_team_participation';

  /// Whether a user's database is open. Asking for it before anyone has
  /// signed in is a normal state at startup, not a failure.
  Future<bool> _isDatabaseOpen() async {
    try {
      await _db.database;
      return true;
    } on StateError {
      return false;
    }
  }

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
      'race_results',
      'team_rosters',
      'race_team_participation',
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

    // Name each bridge row's parents by uuid, so it can be pushed.
    for (final bridge in _bridgeTables) {
      for (final parent in bridge.allParents) {
        await db.rawUpdate('''
          UPDATE ${bridge.table}
          SET ${parent.uuidColumn} = (
            SELECT uuid FROM ${parent.parentTable}
            WHERE ${parent.parentTable}.${parent.parentIdColumn} = ${bridge.table}.${parent.idColumn}
          )
          WHERE ${parent.uuidColumn} IS NULL
        ''');
      }
    }
  }

  // Placeholder: persist cursors in sync_state
  Future<void> setCursor(String key, String value) async {
    final db = await _db.database;
    await db.insert('sync_state', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearSyncCursors() async {
    final db = await _db.database;
    await db.delete('sync_state', where: "key LIKE 'cursor.%'");
    Logger.d('Cleared sync cursors');
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
    // Local integer PKs / FKs — not synced as data columns. Push strips these
    // from the payload, so the remote row has none of them and comparing them
    // would report a difference on every row.
    'id',
    'result_id',
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

  // Only one sync runs at a time. Calls that arrive during a sync share its
  // future and schedule one follow-up pass, so writes made mid-sync still get
  // pushed without overlapping syncs racing on UUIDs, dirty flags and cursors.
  Future<void>? _inFlightSync;
  bool _followUpRequested = false;

  @override
  Future<void> syncAll() {
    if (_inFlightSync != null) {
      _followUpRequested = true;
      return _inFlightSync!;
    }
    final run = _runSyncPasses();
    _inFlightSync = run;
    return run.whenComplete(() => _inFlightSync = null);
  }

  Future<void> _runSyncPasses() async {
    do {
      _followUpRequested = false;
      await _syncOnce();
    } while (_followUpRequested);
  }

  Future<void> _syncOnce() async {
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

      // Connectivity and write events can ask for a sync before the signed-in
      // user's database has been opened. There is nothing to read or write
      // until it is, so wait for the next trigger rather than failing.
      if (!await _isDatabaseOpen()) {
        Logger.d('Sync skipped: no database open yet.');
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
    for (final bridge in _bridgeTables) {
      await _pushBridgeTable(bridge);
    }
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
      copy.remove('team_id');

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

  /// Push dirty rows of a bridge table, naming its parents by uuid.
  ///
  /// Local integer ids are this device's own and mean nothing on another, so
  /// they are stripped; a row whose key uuids are not filled in yet is left
  /// dirty and picked up on a later sync.
  Future<void> _pushBridgeTable(_BridgeTable spec) async {
    final db = await _db.database;

    // Auth guard: defensive check in case this is called outside syncAll().
    final uid = _auth.currentUserId;
    if (uid == null) {
      Logger.d('Push skipped: user is not authenticated (${spec.table}).');
      return;
    }

    final rows = await db.query(spec.table, where: 'is_dirty = 1');
    if (rows.isEmpty) return;

    final payload = <Map<String, dynamic>>[];
    // The local key of each row in payload, in the same order.
    final pushedKeys = <List<Object?>>[];

    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row);
      copy.remove('is_dirty');
      final key = [for (final parent in spec.keyParents) row[parent.idColumn]];
      for (final parent in spec.allParents) {
        copy.remove(parent.idColumn);
      }

      if (spec.keyParents.any((parent) => copy[parent.uuidColumn] == null)) {
        Logger.d('Skipping ${spec.table} row — ${spec.keyColumns} not resolved yet');
        continue;
      }

      copy['owner_user_id'] = uid;
      copy['created_at'] ??=
          copy['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
      payload.add(copy);
      pushedKeys.add(key);
    }

    if (payload.isEmpty) return;

    await _syncClient.upsertRows(spec.table, payload,
        onConflict: spec.conflictTarget);

    // Clear the dirty flag by local primary key: a bridge table has no uuid
    // column locally, so there is nothing else to match these rows on.
    final clause = List.filled(pushedKeys.length, spec.keyWhereClause)
        .join(' OR ');
    await db.rawUpdate(
      'UPDATE ${spec.table} SET is_dirty = 0 WHERE $clause',
      [for (final key in pushedKeys) ...key],
    );
    Logger.d('Pushed ${payload.length} dirty records for ${spec.table}');
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

    Future<void> pullTable(String table, {required String localPkColumn}) async {
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
        // The remote primary key comes from a sequence shared by all users, so
        // it means nothing locally; writing it would clobber an unrelated row.
        // Local rows are matched by uuid and keep their own SQLite id.
        remote.remove(localPkColumn);

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
              (newCursor == null || _PullCursor.isLater(updatedAtStr, newCursor))) {
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
            (newCursor == null || _PullCursor.isLater(updatedAtStr, newCursor))) {
          newCursor = updatedAtStr;
        }
      }
      if (hadWrites) changedTables.add(table);
      if (newCursor != null && newCursor != cursor) {
        await setCursor(cursorKey, newCursor);
      }
    }

    try {
      await pullTable('runners', localPkColumn: 'runner_id');
      await pullTable('teams', localPkColumn: 'team_id');
      await pullTable('races', localPkColumn: 'race_id');
      // Join tables before results: a result takes the team the runner raced
      // for from this device's participant row, and each table's cursor only
      // moves forward, so a result pulled first would never get one.
      for (final bridge in _bridgeTables) {
        await _pullBridgeTable(bridge, accessibleOwnerIds, changedTables);
      }
      await _pullRaceResults(accessibleOwnerIds, changedTables, changedRaceIds);
    } finally {
      // Announce whatever did arrive even if a later table failed, so the
      // screens still refresh instead of showing stale data.
      if (changedTables.isNotEmpty) {
        _syncEventController.add(SyncEvent(
          timestamp: DateTime.now(),
          changedTables: changedTables,
          changedRaceIds: changedRaceIds,
        ));
      }
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

    await _fetchMissingParents(
      db: db,
      parentTable: 'runners',
      parentIdColumn: 'runner_id',
      uuids: runnerUuids,
      resolved: runnerUuidToId,
    );
    await _fetchMissingParents(
      db: db,
      parentTable: 'races',
      parentIdColumn: 'race_id',
      uuids: raceUuids,
      resolved: raceUuidToId,
    );

    // A result's team is the team the runner raced for, which this device
    // records in race_participants. The team_id on the remote row is another
    // device's local id and must not be used.
    final participantTeamIds = <String, int>{};
    final localRaceIds = raceUuidToId.values.toSet().toList();
    if (localRaceIds.isNotEmpty) {
      final qMarks = List.filled(localRaceIds.length, '?').join(',');
      final rows = await db.rawQuery(
          'SELECT race_id, runner_id, team_id FROM race_participants WHERE race_id IN ($qMarks)',
          localRaceIds);
      for (final r in rows) {
        final teamId = r['team_id'] as int?;
        if (teamId != null) {
          participantTeamIds['${r['race_id']}:${r['runner_id']}'] = teamId;
        }
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

    final pullCursor = _PullCursor(cursor);
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
        pullCursor.advance(remote['updated_at']?.toString());
        continue;
      }

      final runnerId = runnerUuidToId[runnerUuid];
      final raceId = raceUuidToId[raceUuid];

      if (runnerId == null || raceId == null) {
        Logger.d(
            'Skipping race_result UUID:$uuid — runner_uuid=$runnerUuid or race_uuid=$raceUuid not yet pulled locally. Will retry on next sync.');
        pullCursor.holdBefore(remote['updated_at']?.toString());
        continue;
      }

      // Inject resolved local integer IDs
      remote['runner_id'] = runnerId;
      remote['race_id'] = raceId;
      remote.remove('team_id');
      final teamId = participantTeamIds['$raceId:$runnerId'];
      if (teamId != null) remote['team_id'] = teamId;

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
        pullCursor.advance(remote['updated_at']?.toString());
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

      pullCursor.advance(remote['updated_at']?.toString());
    }

    if (hadWrites) changedTables.add(table);
    final newCursor = pullCursor.value;
    if (newCursor != null && newCursor != cursor) {
      await setCursor(cursorKey, newCursor);
    }
  }

  /// Fetches parents named in a payload that are not local yet, and inserts
  /// them.
  ///
  /// A pull only asks for rows changed since its cursor, so a runner added to
  /// a race today, but not edited since last season, is never sent again. The
  /// child row would then be held back at every sync from now on, waiting for
  /// a parent that will never arrive on its own.
  Future<void> _fetchMissingParents({
    required Database db,
    required String parentTable,
    required String parentIdColumn,
    required List<String> uuids,
    required Map<String, int> resolved,
  }) async {
    final missing = uuids.where((u) => !resolved.containsKey(u)).toList();
    if (missing.isEmpty) return;

    final rows = await _syncClient.fetchByUuids(parentTable, missing);
    if (rows.isEmpty) return;

    for (final row in rows) {
      final insert = Map<String, dynamic>.from(row)
        ..remove('owner_user_id')
        // The remote id comes from a sequence shared by every user and means
        // nothing here; SQLite assigns its own.
        ..remove(parentIdColumn)
        ..['is_dirty'] = 0;
      await db.insert(parentTable, insert,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final qMarks = List.filled(missing.length, '?').join(',');
    final stored = await db.rawQuery(
      'SELECT uuid, $parentIdColumn FROM $parentTable WHERE uuid IN ($qMarks)',
      missing,
    );
    for (final row in stored) {
      resolved[row['uuid'] as String] = row[parentIdColumn] as int;
    }
    Logger.d('Fetched ${rows.length} $parentTable rows a child row needed');
  }

  /// Pull a bridge table, turning the uuids that name its parents back into
  /// this device's integer ids. A row whose parent has not arrived yet is left
  /// for a later sync rather than dropped.
  ///
  /// Rows are matched on the pair of parents they link, which is the primary
  /// key at both ends. The server also gives each row its own `uuid`, which
  /// has no local column and which two devices can disagree on for the same
  /// pair, so it is never used to match and never written locally.
  Future<void> _pullBridgeTable(
    _BridgeTable spec,
    List<String> accessibleOwnerIds,
    Set<String> changedTables,
  ) async {
    final db = await _db.database;
    final table = spec.table;
    final cursorKey = spec.cursorKey;
    final cursor = await getCursor(cursorKey);

    final data = await _syncClient.fetchTableRows(
      table,
      accessibleOwnerIds,
      cursor: cursor,
    );
    if (data.isEmpty) return;

    // Batch-resolve every parent uuid in the payload to a local integer id.
    final resolved = <String, Map<String, int>>{};
    for (final parent in spec.allParents) {
      final uuids = data
          .map((row) => row[parent.uuidColumn])
          .whereType<String>()
          .toSet()
          .toList();
      final byUuid = <String, int>{};
      if (uuids.isNotEmpty) {
        final qMarks = List.filled(uuids.length, '?').join(',');
        final rows = await db.rawQuery(
          'SELECT uuid, ${parent.parentIdColumn} FROM ${parent.parentTable} WHERE uuid IN ($qMarks)',
          uuids,
        );
        for (final row in rows) {
          byUuid[row['uuid'] as String] = row[parent.parentIdColumn] as int;
        }
      }
      await _fetchMissingParents(
        db: db,
        parentTable: parent.parentTable,
        parentIdColumn: parent.parentIdColumn,
        uuids: uuids,
        resolved: byUuid,
      );
      resolved[parent.uuidColumn] = byUuid;
    }

    // Batch-fetch the local rows that could match, in one query: everything
    // belonging to a parent this payload mentions.
    final anchor = spec.keyParents.first;
    final anchorIds = resolved[anchor.uuidColumn]!.values.toSet().toList();
    final localsByKey = <String, Map<String, dynamic>>{};
    if (anchorIds.isNotEmpty) {
      final qMarks = List.filled(anchorIds.length, '?').join(',');
      final localRows = await db.rawQuery(
        'SELECT * FROM $table WHERE ${anchor.idColumn} IN ($qMarks)',
        anchorIds,
      );
      for (final row in localRows) {
        localsByKey[spec.keyOf(
            [for (final parent in spec.keyParents) row[parent.idColumn]])] = row;
      }
    }

    final pullCursor = _PullCursor(cursor);
    bool hadWrites = false;

    for (final row in data) {
      final remote = Map<String, dynamic>.from(row);
      remote.remove('owner_user_id');
      // The remote surrogate key has no local column to live in.
      remote.remove('uuid');

      final updatedAt = remote['updated_at']?.toString();

      if (spec.keyParents.any((p) => remote[p.uuidColumn] == null)) {
        Logger.d('Skipping $table row — ${spec.keyColumns} missing');
        pullCursor.advance(updatedAt);
        continue;
      }

      // Turn each parent uuid into a local id.
      final ids = <String, int?>{};
      for (final parent in spec.allParents) {
        final uuid = remote[parent.uuidColumn] as String?;
        ids[parent.uuidColumn] =
            uuid == null ? null : resolved[parent.uuidColumn]![uuid];
      }

      if (spec.keyParents.any((p) => ids[p.uuidColumn] == null)) {
        Logger.d(
            'Skipping $table row — a parent is not local yet. Will retry on next sync.');
        pullCursor.holdBefore(updatedAt);
        continue;
      }

      for (final parent in spec.allParents) {
        final id = ids[parent.uuidColumn];
        if (id != null) remote[parent.idColumn] = id;
      }

      final key =
          spec.keyOf([for (final p in spec.keyParents) ids[p.uuidColumn]]);
      final local = localsByKey[key];

      if (remote['deleted_at'] != null) {
        if (local == null) {
          // Nothing to delete: a row this device never had. Storing the
          // tombstone would mean inventing one, and the cursor moves on
          // either way.
          Logger.d('Ignoring remote tombstone for unknown $table row');
        } else if (local['deleted_at'] == null) {
          await db.update(
            table,
            {'deleted_at': remote['deleted_at'], 'is_dirty': 0},
            where: spec.keyWhereClause,
            whereArgs: [for (final p in spec.keyParents) ids[p.uuidColumn]],
          );
          Logger.d('Applied remote tombstone to $table');
          hadWrites = true;
        }
        pullCursor.advance(updatedAt);
        continue;
      }

      if (local == null) {
        // A parent whose local column is NOT NULL has to be resolved first.
        _BridgeParent? missing;
        for (final parent in spec.otherParents) {
          if (ids[parent.uuidColumn] == null) {
            missing = parent;
            break;
          }
        }
        if (missing != null) {
          if (remote[missing.uuidColumn] == null) {
            // The remote row names no parent at all, so waiting will not help.
            Logger.d(
                'Skipping $table row — no ${missing.uuidColumn}, cannot be stored locally');
            pullCursor.advance(updatedAt);
          } else {
            Logger.d(
                'Skipping $table row — ${missing.uuidColumn} not yet pulled locally. Will retry on next sync.');
            pullCursor.holdBefore(updatedAt);
          }
          continue;
        }
        final insert = Map<String, dynamic>.from(remote)..['is_dirty'] = 0;
        await db.insert(table, insert,
            conflictAlgorithm: ConflictAlgorithm.replace);
        hadWrites = true;
      } else {
        final localUpdated =
            DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
        final remoteUpdated = DateTime.tryParse(updatedAt ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        if (remoteUpdated.isAfter(localUpdated)) {
          final update = Map<String, dynamic>.from(remote)..['is_dirty'] = 0;
          await db.update(table, update,
              where: spec.keyWhereClause,
              whereArgs: [for (final p in spec.keyParents) ids[p.uuidColumn]]);
          Logger.d('Updated $table row from remote (remote_newer)');
          hadWrites = true;
        } else {
          Logger.d('Kept local $table row');
        }
      }

      pullCursor.advance(updatedAt);
    }

    if (hadWrites) changedTables.add(table);
    final newCursor = pullCursor.value;
    if (newCursor != null && newCursor != cursor) {
      await setCursor(cursorKey, newCursor);
    }
  }
}
