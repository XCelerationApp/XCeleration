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

  @override
  Future<Database> get database async {
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
}

/// A stand-in for the server: holds rows per table, honours the pull cursor
/// the way PostgREST does, and records everything pushed to it.
class _FakeSyncClient implements IRemoteSyncClient {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  final List<({String table, List<Map<String, dynamic>> rows})> upserts = [];

  /// Tables whose fetch should blow up, to stand in for a server or schema fault.
  final Set<String> failingTables = {};

  @override
  Future<List<String>> fetchAccessibleOwnerIds(String userId) async => [userId];

  @override
  Future<List<Map<String, dynamic>>> fetchTableRows(
    String table,
    List<String> ownerIds, {
    String? cursor,
  }) async {
    if (failingTables.contains(table)) {
      throw StateError('fetch failed for $table');
    }
    final rows = tables[table] ?? const [];
    final visible = rows
        .where((r) =>
            cursor == null || r['updated_at'].toString().compareTo(cursor) > 0)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    visible.sort((a, b) =>
        a['updated_at'].toString().compareTo(b['updated_at'].toString()));
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
    upserts.add((table: table, rows: rows));
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

      final db = await conn.database;
      await db.update(
        'race_participants',
        {'team_uuid': 'chosen-locally', 'updated_at': '2026-06-01T00:00:00Z'},
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
