import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/i_remote_sync_client.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/utils/local_schema.dart';

/// Runs [SyncService] against a real SQLite database created from the app's
/// own schema, so a column the sync code expects but the schema does not have
/// fails here instead of on a phone.
class _InMemoryConnectionProvider implements IDatabaseConnectionProvider {
  Database? _db;

  /// Whether a user has signed in. The real provider refuses to hand out a
  /// database before that, and sync has to cope with being asked early.
  bool opened = true;

  @override
  Future<Database> get database async {
    if (!opened) {
      throw StateError('No database is open.');
    }
    _db ??= await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final stmt in splitSqlStatements(localSchemaSql)) {
            await db.execute(stmt);
          }
        },
      ),
    );
    return _db!;
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  @override
  Future<void> deleteDatabase() async {
    _db = null;
  }

  @override
  Future<void> openForUser(String userId) async {
    opened = true;
  }

  @override
  Future<void> deleteUserData(String userId) async => deleteDatabase();

}

/// A stand-in for the server: holds rows per table, honours the pull cursor
/// the way PostgREST does, and records everything pushed to it.
class _FakeSyncClient implements IRemoteSyncClient {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  final List<({String table, List<Map<String, dynamic>> rows})> upserts = [];

  /// Tables whose fetch should blow up, to stand in for a server or schema fault.
  final Set<String> failingTables = {};

  /// Runs while an upload is on its way, to stand in for the coach editing
  /// the same rows in the meantime.
  Future<void> Function(String table)? whileUploading;

  /// Rows the server refuses, as it would one breaking a uniqueness rule.
  /// An upload containing one fails as a whole, as a Postgres upsert does.
  bool Function(Map<String, dynamic> row)? rejects;

  @override
  Future<List<Map<String, dynamic>>> fetchTableRows(
    String table,
    String ownerId, {
    String? cursor,
  }) async {
    if (failingTables.contains(table)) {
      throw StateError('fetch failed for $table');
    }
    DateTime at(Object? row) =>
        DateTime.parse((row as Map)['updated_at'].toString());
    final after = cursor == null ? null : DateTime.parse(cursor);
    final rows = tables[table] ?? const [];
    // Compared as times, as Postgres does: '...05Z' and '...05.5+00:00' are
    // the same moment written two ways, and text order disagrees with time
    // order on them.
    final visible = rows
        .where((r) => r['owner_user_id'] == ownerId)
        .where((r) => after == null || at(r).isAfter(after))
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    visible.sort((a, b) => at(a).compareTo(at(b)));
    return visible;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchByUuids(
      String table, List<String> uuids) async {
    final rows = tables[table] ?? const [];
    return rows
        .where((r) => uuids.contains(r['uuid']))
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  @override
  Future<void> upsertRows(String table, List<Map<String, dynamic>> rows,
      {required String onConflict}) async {
    await whileUploading?.call(table);
    if (rows.any((row) => rejects?.call(row) ?? false)) {
      throw StateError('duplicate key value violates unique constraint');
    }
    upserts.add((table: table, rows: rows));
    // Keep what was pushed, so the next pull sees it the way the server would.
    final keyColumns = onConflict.split(',');
    final stored = tables.putIfAbsent(table, () => []);
    for (final row in rows) {
      final copy = Map<String, dynamic>.from(row);
      final existing = stored
          .indexWhere((e) => keyColumns.every((k) => e[k] == copy[k]));
      if (existing >= 0) {
        stored[existing] = {...stored[existing], ...copy};
      } else {
        stored.add(copy);
      }
    }
  }
}

class _FakeRemoteApiClient implements IRemoteApiClient {
  @override
  SupabaseClient get client => throw UnimplementedError();

  @override
  bool get isInitialized => true;

  @override
  Future<void> init() async {}
}

class _FakeAuth implements IAuthService {
  @override
  String? get currentUserId => 'owner-1';

  @override
  String? get currentEmail => 'coach@example.com';

  @override
  bool get isSignedIn => true;

  @override
  Future<AuthResponse> signInWithEmailPassword(String e, String p) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> signUpWithEmailPassword(String e, String p) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> verifyEmailOtp(String email, String token) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> verifyPasswordResetOtp(String email, String token) =>
      throw UnimplementedError();

  @override
  Future<void> updatePassword(String newPassword) => throw UnimplementedError();

  @override
  Future<void> resendEmailConfirmation(String email) =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late _InMemoryConnectionProvider conn;
  late _FakeSyncClient remote;
  late SyncService service;

  const raceUuid = 'race-uuid-1';
  const runnerUuid = 'runner-uuid-1';
  const teamUuid = 'team-uuid-1';

  setUp(() {
    conn = _InMemoryConnectionProvider();
    remote = _FakeSyncClient();
    service = SyncService(
      db: conn,
      remote: _FakeRemoteApiClient(),
      syncClient: remote,
      auth: _FakeAuth(),
    );
  });

  tearDown(() async {
    await service.dispose();
    await conn.close();
  });

  /// Puts a race, a runner and a team on the server, all owned by the signed-in
  /// user. The participant row that joins them is added per test.
  void seedRemoteParents({String updatedAt = '2026-01-01T00:00:00Z'}) {
    remote.tables['races'] = [
      {
        'race_id': 900,
        'uuid': raceUuid,
        'owner_user_id': 'owner-1',
        'name': 'Invitational',
        'race_date': '2026-01-01T00:00:00Z',
        'location': 'Park',
        'distance': 5.0,
        'distance_unit': 'km',
        'flow_state': 'setup',
        'created_at': updatedAt,
        'updated_at': updatedAt,
        'deleted_at': null,
      }
    ];
    remote.tables['runners'] = [
      {
        'runner_id': 901,
        'uuid': runnerUuid,
        'owner_user_id': 'owner-1',
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'created_at': updatedAt,
        'updated_at': updatedAt,
        'deleted_at': null,
      }
    ];
    remote.tables['teams'] = [
      {
        'team_id': 902,
        'uuid': teamUuid,
        'owner_user_id': 'owner-1',
        'name': 'Eagles',
        'abbreviation': 'EAG',
        'color': 0,
        'created_at': updatedAt,
        'updated_at': updatedAt,
        'deleted_at': null,
      }
    ];
  }

  /// A server participant row. The server generates a `uuid` for every row;
  /// the local table has no such column, so the pull must not depend on one.
  Map<String, dynamic> remoteParticipant({
    String updatedAt = '2026-01-02T00:00:00Z',
    String? deletedAt,
    String? team = teamUuid,
    String uuid = 'participant-uuid-1',
  }) =>
      {
        'uuid': uuid,
        'race_uuid': raceUuid,
        'runner_uuid': runnerUuid,
        'team_uuid': team,
        'owner_user_id': 'owner-1',
        'created_at': '2026-01-02T00:00:00Z',
        'updated_at': updatedAt,
        'deleted_at': deletedAt,
      };

  Future<List<Map<String, Object?>>> participantRows() async {
    final db = await conn.database;
    return db.query('race_participants');
  }

  group('pulling race_participants', () {
    test('brings a participant down onto a device that has none', () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];

      await service.syncAll();

      final rows = await participantRows();
      expect(rows, hasLength(1));
      expect(rows.first['race_uuid'], raceUuid);
      expect(rows.first['runner_uuid'], runnerUuid);
      expect(rows.first['team_uuid'], teamUuid);
      expect(rows.first['is_dirty'], 0);

      // The local integer ids must point at the rows pulled in the same pass.
      final db = await conn.database;
      final race = (await db.query('races')).single;
      final runner = (await db.query('runners')).single;
      final team = (await db.query('teams')).single;
      expect(rows.first['race_id'], race['race_id']);
      expect(rows.first['runner_id'], runner['runner_id']);
      expect(rows.first['team_id'], team['team_id']);
    });

    test('updates the existing row rather than adding a second one', () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];
      await service.syncAll();

      // The coach moves the runner to another team on their other phone.
      remote.tables['teams']!.add({
        'team_id': 903,
        'uuid': 'team-uuid-2',
        'owner_user_id': 'owner-1',
        'name': 'Hawks',
        'abbreviation': 'HAW',
        'color': 0,
        'created_at': '2026-01-03T00:00:00Z',
        'updated_at': '2026-01-03T00:00:00Z',
        'deleted_at': null,
      });
      remote.tables['race_participants'] = [
        remoteParticipant(
            updatedAt: '2026-01-03T00:00:00Z', team: 'team-uuid-2')
      ];

      await service.syncAll();

      final rows = await participantRows();
      expect(rows, hasLength(1));
      expect(rows.first['team_uuid'], 'team-uuid-2');
    });

    test('matches the local row even when the server row is a stranger',
        () async {
      // The row was created on this device, so it has never seen the uuid the
      // server generated for it. It is still the same participant.
      seedRemoteParents();
      await service.syncAll();

      final db = await conn.database;
      final raceId = (await db.query('races')).single['race_id'];
      final runnerId = (await db.query('runners')).single['runner_id'];
      final teamId = (await db.query('teams')).single['team_id'];
      await db.insert('race_participants', {
        'race_id': raceId,
        'runner_id': runnerId,
        'team_id': teamId,
        'race_uuid': raceUuid,
        'runner_uuid': runnerUuid,
        'team_uuid': teamUuid,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });

      remote.tables['race_participants'] = [
        remoteParticipant(
            updatedAt: '2026-01-04T00:00:00Z', uuid: 'never-seen-here')
      ];

      await service.syncAll();

      expect(await participantRows(), hasLength(1));
    });

    test('applies a deletion made on another device', () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];
      await service.syncAll();

      remote.tables['race_participants'] = [
        remoteParticipant(
            updatedAt: '2026-01-05T00:00:00Z',
            deletedAt: '2026-01-05T00:00:00Z')
      ];
      await service.syncAll();

      final rows = await participantRows();
      expect(rows, hasLength(1));
      expect(rows.first['deleted_at'], '2026-01-05T00:00:00Z');
    });

    test('ignores a deletion for a participant this device never had',
        () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [
        remoteParticipant(deletedAt: '2026-01-05T00:00:00Z')
      ];

      await service.syncAll();

      expect(await participantRows(), isEmpty);
    });

    test('keeps a local change that is newer than the server copy', () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];
      await service.syncAll();

      // The coach moves Alice to another team on this phone.
      final db = await conn.database;
      final chosen = await db.insert('teams', {
        'uuid': 'chosen-locally',
        'name': 'Hawks',
        'color': 0,
        'updated_at': '2026-06-01T00:00:00Z',
      });
      await db.update(
        'race_participants',
        {'team_id': chosen, 'updated_at': '2026-06-01T00:00:00Z', 'is_dirty': 1},
      );

      remote.tables['race_participants'] = [
        remoteParticipant(updatedAt: '2026-03-01T00:00:00Z', team: 'stale')
      ];
      await service.syncAll();

      final rows = await participantRows();
      expect(rows.single['team_uuid'], 'chosen-locally');
    });

    test('retries a participant whose team has not arrived yet', () async {
      seedRemoteParents();
      final heldBackTeam = remote.tables['teams']!;
      remote.tables['teams'] = [];
      remote.tables['race_participants'] = [remoteParticipant()];

      await service.syncAll();
      expect(await participantRows(), isEmpty);

      remote.tables['teams'] = heldBackTeam;
      await service.syncAll();

      expect(await participantRows(), hasLength(1));
    });

    test('moves past a participant the server has no team for', () async {
      seedRemoteParents();
      remote.tables['runners']!.add({
        'runner_id': 904,
        'uuid': 'runner-uuid-2',
        'owner_user_id': 'owner-1',
        'name': 'Bob',
        'grade': 11,
        'bib_number': '102',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'deleted_at': null,
      });
      remote.tables['race_participants'] = [
        remoteParticipant(team: null),
        {
          ...remoteParticipant(
              updatedAt: '2026-01-06T00:00:00Z', uuid: 'participant-uuid-2'),
          'runner_uuid': 'runner-uuid-2',
        },
      ];

      await service.syncAll();

      // The teamless row cannot be stored, but it must not wedge the cursor
      // and block every participant behind it.
      final rows = await participantRows();
      expect(rows, hasLength(1));
      expect(rows.single['runner_uuid'], 'runner-uuid-2');
    });

    test('retries a participant whose race has not arrived yet', () async {
      // The race is withheld, as it would be if it sorted after the
      // participant or failed to pull.
      remote.tables['runners'] = [];
      remote.tables['race_participants'] = [remoteParticipant()];
      seedRemoteParents();
      remote.tables['races'] = [];

      await service.syncAll();
      expect(await participantRows(), isEmpty);

      // The race shows up on a later sync; the participant must not be lost.
      seedRemoteParents();
      await service.syncAll();

      expect(await participantRows(), hasLength(1));
    });
  });

  group('pushing race_participants', () {
    Future<void> seedLocalDirtyParticipant() async {
      final db = await conn.database;
      final raceId = await db.insert('races', {
        'uuid': raceUuid,
        'name': 'Invitational',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      final runnerId = await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      final teamId = await db.insert('teams', {
        'uuid': teamUuid,
        'name': 'Eagles',
        'color': 0,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      await db.insert('race_participants', {
        'race_id': raceId,
        'runner_id': runnerId,
        'team_id': teamId,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 1,
      });
    }

    test('sends the participant and marks it as synced', () async {
      await seedLocalDirtyParticipant();

      await service.syncAll();

      final pushed =
          remote.upserts.where((u) => u.table == 'race_participants').toList();
      expect(pushed, hasLength(1));
      expect(pushed.single.rows.single['race_uuid'], raceUuid);
      expect(pushed.single.rows.single['runner_uuid'], runnerUuid);

      final rows = await participantRows();
      expect(rows.single['is_dirty'], 0,
          reason: 'a pushed row must not stay dirty');
    });

    test('does not send the same participant again on the next sync',
        () async {
      await seedLocalDirtyParticipant();
      await service.syncAll();
      remote.upserts.clear();

      await service.syncAll();

      expect(remote.upserts.where((u) => u.table == 'race_participants'),
          isEmpty);
    });
  });

  group('moving a runner to another team in a race', () {
    test('sends the new team, not the one the row was first synced with',
        () async {
      final db = await conn.database;
      final raceId = await db.insert('races', {
        'uuid': raceUuid,
        'name': 'Invitational',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      final runnerId = await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      final eagles = await db.insert('teams', {
        'uuid': teamUuid,
        'name': 'Eagles',
        'color': 0,
        'updated_at': '2026-01-01T00:00:00Z',
      });
      final hawks = await db.insert('teams', {
        'uuid': 'team-uuid-2',
        'name': 'Hawks',
        'color': 0,
        'updated_at': '2026-01-01T00:00:00Z',
      });
      await db.insert('race_participants', {
        'race_id': raceId,
        'runner_id': runnerId,
        'team_id': eagles,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 1,
      });
      await service.syncAll();

      await db.update(
          'race_participants',
          {'team_id': hawks, 'updated_at': '2026-01-02T00:00:00Z', 'is_dirty': 1},
          where: 'runner_id = ?',
          whereArgs: [runnerId]);
      remote.upserts.clear();
      await service.syncAll();

      final pushed = remote.upserts
          .where((u) => u.table == 'race_participants')
          .single
          .rows
          .single;
      expect(pushed['team_uuid'], 'team-uuid-2');
    });
  });

  group('another coach\'s data', () {
    test('is never pulled onto this coach\'s phone', () async {
      remote.tables['runners'] = [
        {
          'runner_id': 950,
          'uuid': 'someone-elses-runner',
          'owner_user_id': 'another-coach',
          'name': 'Blake',
          'grade': 11,
          'bib_number': '101',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'deleted_at': null,
        }
      ];

      await service.syncAll();

      expect(await (await conn.database).query('runners'), isEmpty);
    });

    test('cannot take the place of the coach\'s own runner with that bib',
        () async {
      // Bibs are unique per coach on the server, but on the phone across
      // everything it holds, so saving Blake would have replaced Alice.
      final db = await conn.database;
      await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      remote.tables['runners'] = [
        {
          'runner_id': 950,
          'uuid': 'someone-elses-runner',
          'owner_user_id': 'another-coach',
          'name': 'Blake',
          'grade': 11,
          'bib_number': '101',
          'created_at': '2026-01-02T00:00:00Z',
          'updated_at': '2026-01-02T00:00:00Z',
          'deleted_at': null,
        }
      ];

      await service.syncAll();

      expect((await db.query('runners')).single['name'], 'Alice');
    });
  });

  group('a row the server refuses', () {
    Future<void> addRunner(String uuid, String bib) async {
      await (await conn.database).insert('runners', {
        'uuid': uuid,
        'name': 'Runner $bib',
        'grade': 10,
        'bib_number': bib,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 1,
      });
    }

    test('does not hold back the rows uploaded with it', () async {
      await addRunner('r1', '101');
      await addRunner('r2', '102');
      await addRunner('r3', '103');
      remote.rejects = (row) => row['bib_number'] == '102';

      await service.syncAll();

      final sent = {for (final r in remote.tables['runners']!) r['bib_number']};
      expect(sent, {'101', '103'});
      final dirty = {
        for (final r in await (await conn.database).query('runners'))
          r['bib_number']: r['is_dirty']
      };
      expect(dirty, {'101': 0, '102': 1, '103': 0},
          reason: 'the refused row waits to be tried again');
    });

    test('the other phone\'s runner with that bib does not replace this one',
        () async {
      // Both phones added bib 102 offline. The server keeps the first to
      // arrive; this phone's runner, and the results pointing at it, stay.
      await addRunner('r2', '102');
      remote.rejects = (row) => row['uuid'] == 'r2';
      remote.tables['runners'] = [
        {
          'runner_id': 950,
          'uuid': 'other-phones-runner',
          'owner_user_id': 'owner-1',
          'name': 'Blake',
          'grade': 11,
          'bib_number': '102',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'deleted_at': null,
        }
      ];

      await service.syncAll();

      final runners = await (await conn.database).query('runners');
      expect([for (final r in runners) r['uuid']], ['r2']);
    });

    test('does not stop the rest of the sync', () async {
      await addRunner('r2', '102');
      remote.rejects = (row) => row['bib_number'] == '102';
      seedRemoteParents();
      remote.tables['runners']!.clear();

      await service.syncAll();

      expect(await (await conn.database).query('teams'), hasLength(1),
          reason: 'pulling still happens after a refused upload');
    });
  });

  group('an edit made while its row is uploading', () {
    test('is still sent on the next sync', () async {
      final db = await conn.database;
      await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 1,
      });
      remote.whileUploading = (table) async {
        if (table != 'runners') return;
        remote.whileUploading = null;
        await db.update(
            'runners', {'name': 'Alicia', 'updated_at': '2026-01-01T00:00:05Z', 'is_dirty': 1},
            where: 'uuid = ?', whereArgs: [runnerUuid]);
      };

      await service.syncAll();

      final row = (await db.query('runners')).single;
      expect(row['name'], 'Alicia');
      expect(row['is_dirty'], 1,
          reason: 'the upload carried the old name, so the new one is unsent');

      await service.syncAll();
      expect(remote.tables['runners']!.single['name'], 'Alicia');
    });

    test('is still sent for a roster row too', () async {
      final db = await conn.database;
      final teamId = await db.insert('teams', {
        'uuid': teamUuid,
        'name': 'Eagles',
        'color': 0,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      final runnerId = await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      await db.insert('team_rosters', {
        'team_id': teamId,
        'runner_id': runnerId,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 1,
      });
      remote.whileUploading = (table) async {
        if (table != 'team_rosters') return;
        remote.whileUploading = null;
        // The coach takes Alice off the team while the add is uploading.
        await db.update('team_rosters',
            {'deleted_at': '2026-01-01T00:00:05Z', 'updated_at': '2026-01-01T00:00:05Z', 'is_dirty': 1});
      };

      await service.syncAll();

      expect((await db.query('team_rosters')).single['is_dirty'], 1,
          reason: 'the removal has not been sent');
    });
  });

  group('team rosters', () {
    /// A roster row on the server saying Alice runs for the Eagles.
    Map<String, dynamic> remoteRoster({
      String updatedAt = '2026-01-02T00:00:00Z',
      String? deletedAt,
    }) =>
        {
          'uuid': 'roster-uuid-1',
          'team_uuid': teamUuid,
          'runner_uuid': runnerUuid,
          'owner_user_id': 'owner-1',
          'created_at': '2026-01-02T00:00:00Z',
          'updated_at': updatedAt,
          'deleted_at': deletedAt,
        };

    test('brings a team roster down onto a device that has none', () async {
      seedRemoteParents();
      remote.tables['team_rosters'] = [remoteRoster()];

      await service.syncAll();

      final db = await conn.database;
      final rows = await db.query('team_rosters');
      expect(rows, hasLength(1),
          reason: 'which runners are on which team has to travel');
      expect(rows.single['team_id'], (await db.query('teams')).single['team_id']);
      expect(
          rows.single['runner_id'], (await db.query('runners')).single['runner_id']);
      expect(rows.single['is_dirty'], 0);
    });

    test('sends a local roster row and marks it as synced', () async {
      final db = await conn.database;
      final teamId = await db.insert('teams', {
        'uuid': teamUuid,
        'name': 'Eagles',
        'color': 0,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      final runnerId = await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      await db.insert('team_rosters', {
        'team_id': teamId,
        'runner_id': runnerId,
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 1,
      });

      await service.syncAll();

      final pushed =
          remote.upserts.where((u) => u.table == 'team_rosters').toList();
      expect(pushed, hasLength(1));
      expect(pushed.single.rows.single['team_uuid'], teamUuid,
          reason: 'the parents have to be named by uuid, not local id');
      expect(pushed.single.rows.single['runner_uuid'], runnerUuid);
      expect(pushed.single.rows.single.containsKey('team_id'), isFalse,
          reason: 'a local id means nothing on another device');

      final rows = await db.query('team_rosters');
      expect(rows.single['is_dirty'], 0);
    });

    test('takes a runner off the team when another device did', () async {
      seedRemoteParents();
      remote.tables['team_rosters'] = [remoteRoster()];
      await service.syncAll();

      remote.tables['team_rosters'] = [
        remoteRoster(
            updatedAt: '2026-01-05T00:00:00Z',
            deletedAt: '2026-01-05T00:00:00Z')
      ];
      await service.syncAll();

      final db = await conn.database;
      final rows = await db.query('team_rosters');
      expect(rows.single['deleted_at'], '2026-01-05T00:00:00Z');
    });

    test('retries a roster row whose runner has not arrived yet', () async {
      seedRemoteParents();
      final heldBack = remote.tables['runners']!;
      remote.tables['runners'] = [];
      remote.tables['team_rosters'] = [remoteRoster()];

      await service.syncAll();
      final db = await conn.database;
      expect(await db.query('team_rosters'), isEmpty);

      remote.tables['runners'] = heldBack;
      await service.syncAll();

      expect(await db.query('team_rosters'), hasLength(1));
    });
  });

  group('teams in a race', () {
    test('brings the race\'s teams down, with their colour override',
        () async {
      seedRemoteParents();
      remote.tables['race_team_participation'] = [
        {
          'uuid': 'rtp-uuid-1',
          'race_uuid': raceUuid,
          'team_uuid': teamUuid,
          'team_color_override': 4283215696,
          'owner_user_id': 'owner-1',
          'created_at': '2026-01-02T00:00:00Z',
          'updated_at': '2026-01-02T00:00:00Z',
          'deleted_at': null,
        }
      ];

      await service.syncAll();

      final db = await conn.database;
      final rows = await db.query('race_team_participation');
      expect(rows, hasLength(1));
      expect(rows.single['team_color_override'], 4283215696);
      expect(rows.single['race_id'], (await db.query('races')).single['race_id']);
    });
  });

  group('the rest of the sync', () {
    test('a result gets its team from the participant pulled alongside it',
        () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];
      remote.tables['race_results'] = [
        {
          'result_id': 500,
          'uuid': 'result-uuid-1',
          'race_uuid': raceUuid,
          'runner_uuid': runnerUuid,
          'race_id': 900,
          'runner_id': 901,
          'team_id': 902,
          'owner_user_id': 'owner-1',
          'place': 1,
          'finish_time': 900000,
          'created_at': '2026-01-02T00:00:00Z',
          'updated_at': '2026-01-02T00:00:00Z',
          'deleted_at': null,
        }
      ];

      await service.syncAll();

      final db = await conn.database;
      final result = (await db.query('race_results')).single;
      final team = (await db.query('teams')).single;
      expect(result['team_id'], team['team_id'],
          reason:
              'team scoring needs the result to know which team the runner ran for');
    });

    test('does not treat a result it just pushed as changed on the way back',
        () async {
      final db = await conn.database;
      final raceId = await db.insert('races', {
        'uuid': raceUuid,
        'name': 'Invitational',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      final runnerId = await db.insert('runners', {
        'uuid': runnerUuid,
        'name': 'Alice',
        'grade': 10,
        'bib_number': '101',
        'updated_at': '2026-01-01T00:00:00Z',
        'is_dirty': 0,
      });
      await db.insert('race_results', {
        'uuid': 'result-uuid-1',
        'race_id': raceId,
        'runner_id': runnerId,
        'race_uuid': raceUuid,
        'runner_uuid': runnerUuid,
        'place': 1,
        'finish_time': 900000,
        'updated_at': '2026-01-02T00:00:00Z',
        'is_dirty': 1,
      });

      final events = <SyncEvent>[];
      final sub = service.syncEvents.listen(events.add);
      await service.syncAll();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // result_id is this device's own key and is stripped before pushing, so
      // finding it absent from the row that comes back is not a change.
      expect(events.expand((e) => e.changedTables), isNot(contains('race_results')),
          reason: 'a row this device just pushed has not changed');

      final result = (await db.query('race_results')).single;
      expect(result['result_id'], isNotNull,
          reason: 'the local key must survive the round trip');
    });

    test('moves the cursor on for a timestamp written a different way',
        () async {
      // '...05Z' and '...05.5+00:00' are half a second apart, but as text the
      // '.' sorts before the 'Z', so the later row looks earlier. A cursor
      // that does not move re-fetches the same rows on every sync for good.
      seedRemoteParents(updatedAt: '2026-02-01T00:00:05Z');
      await service.syncAll();

      remote.tables['runners']!.single['name'] = 'Alice Renamed';
      remote.tables['runners']!.single['updated_at'] =
          '2026-02-01T00:00:05.500+00:00';
      await service.syncAll();

      final db = await conn.database;
      final cursor = (await db.query('sync_state',
              where: 'key = ?', whereArgs: ['cursor.runners']))
          .single['value'];
      expect(cursor, '2026-02-01T00:00:05.500+00:00',
          reason: 'the cursor has to move past the row it just applied');
      expect((await db.query('runners')).single['name'], 'Alice Renamed');
    });

    test('fetches a parent that will never be sent again', () async {
      // The runner was last edited a season ago and is added to a race today.
      // A pull only asks for rows changed since its cursor, so the runner is
      // never sent, and the participant would be held back at every sync from
      // now on waiting for them.
      seedRemoteParents(updatedAt: '2026-01-01T00:00:00Z');
      await service.syncAll();

      final db = await conn.database;
      await db.delete('runners');
      expect(await db.query('runners'), isEmpty);

      remote.tables['race_participants'] = [
        remoteParticipant(updatedAt: '2026-06-01T00:00:00Z')
      ];
      await service.syncAll();

      expect(await db.query('runners'), hasLength(1),
          reason: 'the runner the participant needs has to be fetched');
      expect(await participantRows(), hasLength(1));
    });

    test('waits rather than failing when no one has signed in yet', () async {
      // Connectivity and write events can ask for a sync at startup, before
      // the signed-in user's database has been opened.
      conn.opened = false;
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];

      await service.syncAll();

      conn.opened = true;
      await service.syncAll();
      expect(await participantRows(), hasLength(1),
          reason: 'the sync that was skipped has to happen once it can');
    });

    test('still reports what did arrive when a later table fails', () async {
      seedRemoteParents();
      remote.tables['race_participants'] = [remoteParticipant()];
      remote.failingTables.add('race_participants');

      final events = <SyncEvent>[];
      final sub = service.syncEvents.listen(events.add);

      await expectLater(service.syncAll(), throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(1),
          reason: 'screens must still refresh for the tables that pulled');
      expect(events.single.changedTables, contains('runners'));
    });
  });
}
