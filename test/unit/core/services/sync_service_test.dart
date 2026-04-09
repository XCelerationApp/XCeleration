import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/i_remote_sync_client.dart';
import 'package:xceleration/core/services/sync_service.dart';

@GenerateMocks([
  IDatabaseConnectionProvider,
  IRemoteApiClient,
  IRemoteSyncClient,
  IAuthService,
  Database,
  Transaction,
  SupabaseClient,
])
import 'sync_service_test.mocks.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Stubs the schema check so all five normalized tables appear to exist.
void _stubSchemaExists(MockDatabase db) {
  when(db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    any,
  )).thenAnswer((_) async => [
        {'name': 'table'}
      ]);
}

/// Stubs the schema check so no tables exist (schema missing).
void _stubSchemaMissing(MockDatabase db) {
  when(db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    any,
  )).thenAnswer((_) async => []);
}

/// Stubs sync_state so every getCursor call returns null (no cursor stored).
void _stubNoCursors(MockDatabase db) {
  when(db.query(
    'sync_state',
    where: anyNamed('where'),
    whereArgs: anyNamed('whereArgs'),
  )).thenAnswer((_) async => []);
}

/// Stubs every fetchTableRows call to return an empty list by default.
void _stubEmptyRemoteTables(MockIRemoteSyncClient syncClient) {
  when(syncClient.fetchTableRows(
    any,
    any,
    cursor: anyNamed('cursor'),
  )).thenAnswer((_) async => []);
}

void main() {
  late SyncService service;
  late MockIDatabaseConnectionProvider mockConnProvider;
  late MockIRemoteApiClient mockRemote;
  late MockIRemoteSyncClient mockSyncClient;
  late MockIAuthService mockAuth;
  late MockDatabase mockDatabase;

  setUp(() {
    mockConnProvider = MockIDatabaseConnectionProvider();
    mockRemote = MockIRemoteApiClient();
    mockSyncClient = MockIRemoteSyncClient();
    mockAuth = MockIAuthService();
    mockDatabase = MockDatabase();

    service = SyncService(
      db: mockConnProvider,
      remote: mockRemote,
      syncClient: mockSyncClient,
      auth: mockAuth,
    );

    when(mockConnProvider.database).thenAnswer((_) async => mockDatabase);
    when(mockConnProvider.openForUser(any)).thenAnswer((_) async {});
    when(mockRemote.init()).thenAnswer((_) async {});
    when(mockRemote.isInitialized).thenReturn(false);
    // Default to unauthenticated; individual tests override as needed.
    when(mockAuth.isSignedIn).thenReturn(false);
    when(mockAuth.currentUserId).thenReturn(null);
  });

  // ===========================================================================
  group('SyncService', () {
    // -------------------------------------------------------------------------
    group('syncAll', () {
      test('skips all sync when remote is not initialized after init()', () async {
        when(mockRemote.isInitialized).thenReturn(false);

        await service.syncAll();

        verify(mockRemote.init()).called(1);
        verifyNever(mockConnProvider.database);
      });

      test('skips push and pull when user is not authenticated', () async {
        when(mockRemote.isInitialized).thenReturn(true);
        when(mockAuth.isSignedIn).thenReturn(false);

        await service.syncAll();

        verifyNever(mockConnProvider.database);
        verifyNever(mockDatabase.rawQuery(any, any));
      });

      test('rethrows exceptions from underlying operations', () async {
        when(mockRemote.isInitialized).thenReturn(true);
        when(mockAuth.isSignedIn).thenReturn(true);
        when(mockAuth.currentUserId).thenReturn('user-1');
        when(mockConnProvider.database).thenThrow(Exception('db failure'));

        await expectLater(service.syncAll(), throwsA(isA<Exception>()));
      });
    });

    // -------------------------------------------------------------------------
    group('pushAll', () {
      test('skips all tables when normalized schema is not present', () async {
        when(mockAuth.currentUserId).thenReturn('user-1');
        _stubSchemaMissing(mockDatabase);

        await service.pushAll();

        verifyNever(mockSyncClient.upsertRows(any, any,
            onConflict: anyNamed('onConflict')));
      });

      test('skips upsert for table when no dirty rows exist', () async {
        when(mockAuth.currentUserId).thenReturn('user-1');
        _stubSchemaExists(mockDatabase);
        // No dirty rows for any table
        when(mockDatabase.query(any, where: anyNamed('where')))
            .thenAnswer((_) async => []);
        when(mockSyncClient.fetchByUuids(any, any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => []);

        await service.pushAll();

        verifyNever(mockSyncClient.upsertRows(any, any,
            onConflict: anyNamed('onConflict')));
      });

      test('skips push when currentUserId is null', () async {
        when(mockAuth.currentUserId).thenReturn(null);

        await service.pushAll();

        verifyNever(mockSyncClient.upsertRows(any, any,
            onConflict: anyNamed('onConflict')));
        verifyNever(mockDatabase.rawQuery(any, any));
      });
    });

    // -------------------------------------------------------------------------
    group('ensureLocalUuids', () {
      test('skips UUID assignment when normalized schema is absent', () async {
        _stubSchemaMissing(mockDatabase);

        await service.ensureLocalUuids();

        verifyNever(mockDatabase.update(any, any,
            where: anyNamed('where'), whereArgs: anyNamed('whereArgs')));
        verifyNever(mockDatabase.rawUpdate(any, any));
      });

      test('assigns UUIDs to rows that have a null uuid', () async {
        _stubSchemaExists(mockDatabase);

        // Return one null-uuid row for 'runners', empty for others
        when(mockDatabase.query(
          'runners',
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
              {'runner_id': 1}
            ]);
        when(mockDatabase.query(
          argThat(isNot('runners')),
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 0);
        when(mockDatabase.rawUpdate(any)).thenAnswer((_) async => 0);

        // UUID assignment wraps updates in a transaction; forward the
        // callback to a MockTransaction so the update stub can be verified.
        final mockTxn = MockTransaction();
        when(mockTxn.update(any, any,
                where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);
        when(mockDatabase.transaction<void>(any,
                exclusive: anyNamed('exclusive')))
            .thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0]
              as Future<void> Function(Transaction);
          // Return Future<Null> (not Future<void>) so the mock's internal
          // "as Future<T>" cast succeeds when Dart infers T=Null for the lambda.
          return callback(mockTxn).then<Null>((_) => null);
        });

        await service.ensureLocalUuids();

        final captured = verify(mockTxn.update(
          'runners',
          captureAny,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).captured;

        expect(captured.first, isA<Map<String, dynamic>>());
        final updatedValues = captured.first as Map<String, dynamic>;
        expect(updatedValues.containsKey('uuid'), isTrue);
        expect(updatedValues['uuid'], isA<String>());
        expect((updatedValues['uuid'] as String).isNotEmpty, isTrue);
      });

      test('skips db.update when all rows already have UUIDs', () async {
        _stubSchemaExists(mockDatabase);

        // All tables return empty → no null-uuid rows
        when(mockDatabase.query(
          any,
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);
        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 0);
        when(mockDatabase.rawUpdate(any)).thenAnswer((_) async => 0);

        await service.ensureLocalUuids();

        verifyNever(mockDatabase.update(any, any,
            where: anyNamed('where'), whereArgs: anyNamed('whereArgs')));
      });
    });

    // -------------------------------------------------------------------------
    group('getCursor', () {
      test('returns null when key has no record in sync_state', () async {
        when(mockDatabase.query(
          'sync_state',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => []);

        final result = await service.getCursor('cursor.runners');

        expect(result, isNull);
      });

      test('returns the stored value when key exists', () async {
        const storedCursor = '2024-06-01T12:00:00.000Z';
        when(mockDatabase.query(
          'sync_state',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => [
              {'key': 'cursor.runners', 'value': storedCursor}
            ]);

        final result = await service.getCursor('cursor.runners');

        expect(result, storedCursor);
      });
    });

    // -------------------------------------------------------------------------
    group('setCursor', () {
      test('inserts key-value pair with replace conflict algorithm', () async {
        when(mockDatabase.insert(any, any,
                conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .thenAnswer((_) async => 1);

        await service.setCursor('cursor.runners', '2024-06-01T12:00:00.000Z');

        verify(mockDatabase.insert(
          'sync_state',
          {'key': 'cursor.runners', 'value': '2024-06-01T12:00:00.000Z'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        )).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('clearSyncCursors', () {
      test('deletes all cursor.* rows from sync_state', () async {
        when(mockDatabase.delete(any, where: anyNamed('where')))
            .thenAnswer((_) async => 0);

        await service.clearSyncCursors();

        verify(mockDatabase.delete(
          'sync_state',
          where: "key LIKE 'cursor.%'",
        )).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('pullAll', () {
      setUp(() {
        // Common setup for pullAll tests: schema exists, user authenticated
        _stubSchemaExists(mockDatabase);
        when(mockAuth.currentUserId).thenReturn('user-1');
        when(mockSyncClient.fetchAccessibleOwnerIds('user-1'))
            .thenAnswer((_) async => ['user-1']);
        _stubEmptyRemoteTables(mockSyncClient);
        _stubNoCursors(mockDatabase);
        when(mockDatabase.insert(any, any,
                conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .thenAnswer((_) async => 1);
        when(mockDatabase.insert(any, any)).thenAnswer((_) async => 1);
        when(mockDatabase.update(any, any,
                where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);
        // pullTable now batch-fetches local rows with rawQuery instead of
        // per-row query(). Default: no matching local rows.
        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => []);
      });

      test('skips all pulls when normalized schema is not present', () async {
        _stubSchemaMissing(mockDatabase);

        await service.pullAll();

        verifyNever(mockSyncClient.fetchTableRows(any, any,
            cursor: anyNamed('cursor')));
      });

      test('inserts remote row when no local row exists', () async {
        const uuid = 'uuid-runner-1';
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': '2024-06-01T12:00:00.000Z',
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        // No local row found for this UUID
        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => []);

        await service.pullAll();

        final insertCall = verify(mockDatabase.insert(
          'runners',
          captureAny,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        ));
        insertCall.called(1);
        final inserted = insertCall.captured.first as Map<String, dynamic>;
        expect(inserted['uuid'], uuid);
        expect(inserted['is_dirty'], 0);
        // owner_user_id must be stripped before local insert
        expect(inserted.containsKey('owner_user_id'), isFalse);
      });

      test('updates local row when remote timestamp is newer', () async {
        const uuid = 'uuid-runner-1';
        final localRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': '2024-01-01T00:00:00.000Z',
          'is_dirty': 0,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice Updated',
          'updated_at': '2024-06-01T12:00:00.000Z',
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verify(mockDatabase.update(
          'runners',
          argThat(containsPair('name', 'Alice Updated')),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).called(1);
      });

      test('keeps local row when local timestamp is newer', () async {
        const uuid = 'uuid-runner-1';
        final localRow = {
          'uuid': uuid,
          'name': 'Alice Local',
          'updated_at': '2024-12-01T00:00:00.000Z',
          'is_dirty': 0,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice Remote',
          'updated_at': '2024-01-01T00:00:00.000Z',
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verifyNever(mockDatabase.update(
          'runners',
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ));
      });

      test('updates local when timestamps are equal but data differs', () async {
        const uuid = 'uuid-runner-1';
        const ts = '2024-06-01T12:00:00.000Z';
        final localRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': ts,
          'is_dirty': 0,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice Modified',
          'updated_at': ts,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verify(mockDatabase.update(
          'runners',
          argThat(containsPair('name', 'Alice Modified')),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).called(1);
      });

      test('no-op when timestamps are equal and data is identical', () async {
        const uuid = 'uuid-runner-1';
        const ts = '2024-06-01T12:00:00.000Z';
        final localRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': ts,
          'is_dirty': 0,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': ts,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verifyNever(mockDatabase.update(
          'runners',
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ));
      });

      test(
          'clears is_dirty flag when local is dirty and remote wins LWW (small time diff)',
          () async {
        const uuid = 'uuid-runner-1';
        // Remote is 2 minutes newer than local — remote still wins LWW
        final localRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': '2024-06-01T12:00:00.000Z',
          'is_dirty': 1,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice Remote',
          'updated_at': '2024-06-01T12:02:00.000Z',
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        final captured = verify(mockDatabase.update(
          'runners',
          captureAny,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).captured;

        final updated = captured.first as Map<String, dynamic>;
        expect(updated['is_dirty'], 0,
            reason: 'dirty flag is always cleared when remote wins LWW');
      });

      test('clears is_dirty flag when remote is significantly newer (>= 5 min)',
          () async {
        const uuid = 'uuid-runner-1';
        // Remote is 10 minutes newer — dirty flag should be cleared
        final localRow = {
          'uuid': uuid,
          'name': 'Alice',
          'updated_at': '2024-06-01T12:00:00.000Z',
          'is_dirty': 1,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice Remote',
          'updated_at': '2024-06-01T12:10:00.000Z',
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        final captured = verify(mockDatabase.update(
          'runners',
          captureAny,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).captured;

        final updated = captured.first as Map<String, dynamic>;
        expect(updated['is_dirty'], 0,
            reason: 'dirty flag must be cleared when diff >= 5 minutes');
      });

      test(
          'updates local when timestamps are equal and an unrecognised new column differs',
          () async {
        // Verifies the schema-driven approach: an arbitrary column not in any
        // hardcoded list is still detected as a conflict when its value differs.
        const uuid = 'uuid-runner-1';
        const ts = '2024-06-01T12:00:00.000Z';
        final localRow = {
          'uuid': uuid,
          'name': 'Alice',
          'new_arbitrary_column': 'old_value',
          'updated_at': ts,
          'is_dirty': 0,
        };
        final remoteRow = {
          'uuid': uuid,
          'name': 'Alice',
          'new_arbitrary_column': 'new_value',
          'updated_at': ts,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('WHERE uuid IN')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verify(mockDatabase.update(
          'runners',
          argThat(containsPair('new_arbitrary_column', 'new_value')),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).called(1);
      });

      test('emits SyncEvent after a pull that wrote at least one row', () async {
        const uuid = 'uuid-runner-1';
        final remoteRow = {
          'uuid': uuid,
          'name': 'Bob',
          'updated_at': '2024-06-01T12:00:00.000Z',
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'runners',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        // Use expectLater so the stream subscription is active before pullAll runs.
        final streamExpectation = expectLater(
          service.syncEvents,
          emits(isA<SyncEvent>().having(
              (e) => e.changedTables, 'changedTables', contains('runners'))),
        );

        await service.pullAll();
        await streamExpectation;
      });

      // -----------------------------------------------------------------------
      group('race_results pull — cursor', () {
      test(
          'does not advance cursor past a skipped row when runner UUID is unresolved',
          () async {
        const runnerUuidExists = 'runner-uuid-exists';
        const runnerUuidMissing = 'runner-uuid-missing';
        const raceUuid = 'race-uuid-1';
        const t1 = '2024-01-01T10:00:00.000Z';
        const t2 = '2024-01-01T11:00:00.000Z';

        final row1 = {
          'uuid': 'result-uuid-1',
          'runner_uuid': runnerUuidExists,
          'race_uuid': raceUuid,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };
        // row2 has a later updated_at but an unresolvable runner_uuid
        final row2 = {
          'uuid': 'result-uuid-2',
          'runner_uuid': runnerUuidMissing,
          'race_uuid': raceUuid,
          'updated_at': t2,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'race_results',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [row1, row2]);

        // Only the existing runner resolves
        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuidExists, 'runner_id': 1}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuid, 'race_id': 10}
            ]);

        // Missing runner not found on remote either — targeted fetch returns empty
        when(mockSyncClient.fetchByUuids('runners', any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => []);

        // No existing local race_results
        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_results WHERE')),
          any,
        )).thenAnswer((_) async => []);

        await service.pullAll();

        final captured = verify(mockDatabase.insert(
          'sync_state',
          captureAny,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        )).captured;

        final cursorSave = captured
            .cast<Map<String, dynamic>>()
            .firstWhere((m) => m['key'] == 'cursor.race_results');
        expect(cursorSave['value'], t1,
            reason: 'cursor must not advance past the skipped row at t2');
      });

      test(
          'rolls back cursor when skipped row shares the same timestamp as a processed row',
          () async {
        const runnerUuidExists = 'runner-uuid-exists';
        const runnerUuidMissing = 'runner-uuid-missing';
        const raceUuid = 'race-uuid-1';
        const t1 = '2024-01-01T10:00:00.000Z';

        final row1 = {
          'uuid': 'result-uuid-1',
          'runner_uuid': runnerUuidExists,
          'race_uuid': raceUuid,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };
        // row2 has the SAME updated_at as row1 but an unresolvable runner_uuid
        final row2 = {
          'uuid': 'result-uuid-2',
          'runner_uuid': runnerUuidMissing,
          'race_uuid': raceUuid,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'race_results',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [row1, row2]);

        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuidExists, 'runner_id': 1}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuid, 'race_id': 10}
            ]);

        // Missing runner not found on remote either — targeted fetch returns empty
        when(mockSyncClient.fetchByUuids('runners', any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => []);

        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_results WHERE')),
          any,
        )).thenAnswer((_) async => []);

        // Capture all sync_state inserts so we can assert on them.
        final syncStateInserts = <Map<String, dynamic>>[];
        when(mockDatabase.insert(
          'sync_state',
          any,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        )).thenAnswer((inv) {
          syncStateInserts
              .add(Map<String, dynamic>.from(inv.positionalArguments[1] as Map));
          return Future.value(1);
        });

        await service.pullAll();

        final cursorSaves = syncStateInserts
            .where((m) => m['key'] == 'cursor.race_results')
            .toList();
        // Cursor must not have been saved at t1 — it must remain at its
        // previous value (null/empty) so row2 is re-fetched on the next sync.
        expect(cursorSaves, isEmpty,
            reason:
                'cursor must not advance when a same-timestamp row is skipped');
      });
    });

    // -------------------------------------------------------------------------
    group('race_participants pull — cursor', () {
      test(
          'does not advance cursor past a skipped row when race UUID is unresolved',
          () async {
        const runnerUuid = 'runner-uuid-1';
        const raceUuidExists = 'race-uuid-exists';
        const raceUuidMissing = 'race-uuid-missing';
        const t1 = '2024-02-01T10:00:00.000Z';
        const t2 = '2024-02-01T11:00:00.000Z';

        final row1 = {
          'uuid': 'participant-uuid-1',
          'race_uuid': raceUuidExists,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };
        // row2 has a later updated_at but an unresolvable race_uuid
        final row2 = {
          'uuid': 'participant-uuid-2',
          'race_uuid': raceUuidMissing,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': t2,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'race_participants',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [row1, row2]);

        // Only the existing race resolves
        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuidExists, 'race_id': 10}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuid, 'runner_id': 1}
            ]);

        // Missing race not found on remote either — targeted fetch returns empty
        when(mockSyncClient.fetchByUuids('races', any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => []);

        // No existing local race_participants
        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_participants WHERE')),
          any,
        )).thenAnswer((_) async => []);

        await service.pullAll();

        final captured = verify(mockDatabase.insert(
          'sync_state',
          captureAny,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        )).captured;

        final cursorSave = captured
            .cast<Map<String, dynamic>>()
            .firstWhere((m) => m['key'] == 'cursor.race_participants');
        expect(cursorSave['value'], t1,
            reason: 'cursor must not advance past the skipped row at t2');
      });

      test(
          'rolls back cursor when skipped row shares the same timestamp as a processed row',
          () async {
        const runnerUuid = 'runner-uuid-1';
        const raceUuidExists = 'race-uuid-exists';
        const raceUuidMissing = 'race-uuid-missing';
        const t1 = '2024-02-01T10:00:00.000Z';

        final row1 = {
          'uuid': 'participant-uuid-1',
          'race_uuid': raceUuidExists,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };
        // row2 has the SAME updated_at as row1 but an unresolvable race_uuid
        final row2 = {
          'uuid': 'participant-uuid-2',
          'race_uuid': raceUuidMissing,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'race_participants',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [row1, row2]);

        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuidExists, 'race_id': 10}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuid, 'runner_id': 1}
            ]);

        // Missing race not found on remote either — targeted fetch returns empty
        when(mockSyncClient.fetchByUuids('races', any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => []);

        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_participants WHERE')),
          any,
        )).thenAnswer((_) async => []);

        // Capture all sync_state inserts so we can assert on them.
        final syncStateInserts = <Map<String, dynamic>>[];
        when(mockDatabase.insert(
          'sync_state',
          any,
          conflictAlgorithm: anyNamed('conflictAlgorithm'),
        )).thenAnswer((inv) {
          syncStateInserts
              .add(Map<String, dynamic>.from(inv.positionalArguments[1] as Map));
          return Future.value(1);
        });

        await service.pullAll();

        final cursorSaves = syncStateInserts
            .where((m) => m['key'] == 'cursor.race_participants')
            .toList();
        // Cursor must not have been saved at t1 — it must remain at its
        // previous value (null/empty) so row2 is re-fetched on the next sync.
        expect(cursorSaves, isEmpty,
            reason:
                'cursor must not advance when a same-timestamp row is skipped');
      });
    });

    // -------------------------------------------------------------------------
    group('targeted fetch — resolves missing dependencies from remote', () {
      test(
          'race_results: fetches missing runner from remote and inserts result',
          () async {
        const runnerUuid = 'runner-uuid-missing';
        const raceUuid = 'race-uuid-1';
        const t1 = '2024-01-01T10:00:00.000Z';

        final remoteResult = {
          'uuid': 'result-uuid-1',
          'runner_uuid': runnerUuid,
          'race_uuid': raceUuid,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'race_results',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteResult]);

        // Runner not in local DB on first query; resolves after targeted fetch
        var runnerQueryCalls = 0;
        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async {
          runnerQueryCalls++;
          if (runnerQueryCalls == 1) return [];
          return [{'uuid': runnerUuid, 'runner_id': 5}];
        });

        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuid, 'race_id': 10}
            ]);

        when(mockSyncClient.fetchByUuids('runners', any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => [
                  {
                    'uuid': runnerUuid,
                    'runner_id': 5,
                    'name': 'Test Runner',
                    'updated_at': t1,
                    'owner_user_id': 'user-1',
                  }
                ]);

        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_results WHERE')),
          any,
        )).thenAnswer((_) async => []);

        await service.pullAll();

        verify(mockSyncClient.fetchByUuids('runners',
                argThat(contains(runnerUuid)),
                ownerIds: anyNamed('ownerIds')))
            .called(1);
        verify(mockDatabase.insert('runners', any,
                conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .called(1);
        verify(mockDatabase.insert('race_results', any,
                conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .called(greaterThanOrEqualTo(1));
      });

      test(
          'race_participants: fetches missing race from remote and inserts participant',
          () async {
        const runnerUuid = 'runner-uuid-1';
        const raceUuid = 'race-uuid-missing';
        const t1 = '2024-02-01T10:00:00.000Z';

        final remoteParticipant = {
          'uuid': 'participant-uuid-1',
          'race_uuid': raceUuid,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': t1,
          'owner_user_id': 'user-1',
        };

        when(mockSyncClient.fetchTableRows(
          'race_participants',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteParticipant]);

        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuid, 'runner_id': 1}
            ]);

        // Race not in local DB on first query; resolves after targeted fetch
        var raceQueryCalls = 0;
        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async {
          raceQueryCalls++;
          if (raceQueryCalls == 1) return [];
          return [{'uuid': raceUuid, 'race_id': 20}];
        });

        when(mockSyncClient.fetchByUuids('races', any,
                ownerIds: anyNamed('ownerIds')))
            .thenAnswer((_) async => [
                  {
                    'uuid': raceUuid,
                    'race_id': 20,
                    'name': 'Test Race',
                    'updated_at': t1,
                    'owner_user_id': 'user-1',
                  }
                ]);

        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_participants WHERE')),
          any,
        )).thenAnswer((_) async => []);

        await service.pullAll();

        verify(mockSyncClient.fetchByUuids('races',
                argThat(contains(raceUuid)),
                ownerIds: anyNamed('ownerIds')))
            .called(1);
        verify(mockDatabase.insert('races', any,
                conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .called(1);
        verify(mockDatabase.insert('race_participants', any,
                conflictAlgorithm: anyNamed('conflictAlgorithm')))
            .called(greaterThanOrEqualTo(1));
      });
    });

    // -------------------------------------------------------------------------
    group('race_participants pull — equal-timestamp conflict detection', () {
      test('no-op when timestamps are equal and data is identical', () async {
        const participantUuid = 'participant-uuid-1';
        const raceUuid = 'race-uuid-1';
        const runnerUuid = 'runner-uuid-1';
        const ts = '2024-06-01T12:00:00.000Z';

        final remoteRow = {
          'uuid': participantUuid,
          'race_uuid': raceUuid,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': ts,
          'owner_user_id': 'user-1',
        };
        final localRow = {
          'uuid': participantUuid,
          'race_uuid': raceUuid,
          'runner_uuid': runnerUuid,
          'team_uuid': null,
          'updated_at': ts,
          'is_dirty': 0,
          'race_id': 10,
          'runner_id': 1,
        };

        when(mockSyncClient.fetchTableRows(
          'race_participants',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuid, 'race_id': 10}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuid, 'runner_id': 1}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_participants WHERE')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verifyNever(mockDatabase.update(
          'race_participants',
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ));
      });

      test('updates local when timestamps are equal but team_uuid differs',
          () async {
        const participantUuid = 'participant-uuid-1';
        const raceUuid = 'race-uuid-1';
        const runnerUuid = 'runner-uuid-1';
        const ts = '2024-06-01T12:00:00.000Z';

        final remoteRow = {
          'uuid': participantUuid,
          'race_uuid': raceUuid,
          'runner_uuid': runnerUuid,
          'team_uuid': 'team-uuid-new',
          'updated_at': ts,
          'owner_user_id': 'user-1',
        };
        final localRow = {
          'uuid': participantUuid,
          'race_uuid': raceUuid,
          'runner_uuid': runnerUuid,
          'team_uuid': 'team-uuid-old',
          'updated_at': ts,
          'is_dirty': 0,
          'race_id': 10,
          'runner_id': 1,
          'team_id': 5,
        };

        when(mockSyncClient.fetchTableRows(
          'race_participants',
          any,
          cursor: anyNamed('cursor'),
        )).thenAnswer((_) async => [remoteRow]);

        when(mockDatabase.rawQuery(
          argThat(contains('race_id FROM races')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': raceUuid, 'race_id': 10}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('runner_id FROM runners')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': runnerUuid, 'runner_id': 1}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('team_id FROM teams')),
          any,
        )).thenAnswer((_) async => [
              {'uuid': 'team-uuid-new', 'team_id': 6}
            ]);

        when(mockDatabase.rawQuery(
          argThat(contains('FROM race_participants WHERE')),
          any,
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verify(mockDatabase.update(
          'race_participants',
          argThat(containsPair('team_uuid', 'team-uuid-new')),
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('ensureLocalUuids — race_participants', () {
      test('assigns UUIDs to race_participants rows with null uuid', () async {
        _stubSchemaExists(mockDatabase);

        // Return one null-uuid row for 'race_participants', empty for all others
        when(mockDatabase.query(
          'race_participants',
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
              {'race_id': 1, 'runner_id': 2}
            ]);
        when(mockDatabase.query(
          argThat(isNot('race_participants')),
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 0);
        when(mockDatabase.rawUpdate(any)).thenAnswer((_) async => 0);

        final mockTxn = MockTransaction();
        when(mockTxn.update(any, any,
                where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);
        when(mockDatabase.transaction<void>(any,
                exclusive: anyNamed('exclusive')))
            .thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0]
              as Future<void> Function(Transaction);
          return callback(mockTxn).then<Null>((_) => null);
        });

        await service.ensureLocalUuids();

        final captured = verify(mockTxn.update(
          'race_participants',
          captureAny,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).captured;

        expect(captured.first, isA<Map<String, dynamic>>());
        final updatedValues = captured.first as Map<String, dynamic>;
        expect(updatedValues.containsKey('uuid'), isTrue);
        expect(updatedValues['uuid'], isA<String>());
        expect((updatedValues['uuid'] as String).isNotEmpty, isTrue);
      });

      test('identifies race_participants rows by composite PK (race_id, runner_id)',
          () async {
        _stubSchemaExists(mockDatabase);

        when(mockDatabase.query(
          'race_participants',
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => [
              {'race_id': 10, 'runner_id': 20}
            ]);
        when(mockDatabase.query(
          argThat(isNot('race_participants')),
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 0);
        when(mockDatabase.rawUpdate(any)).thenAnswer((_) async => 0);

        final mockTxn = MockTransaction();
        when(mockTxn.update(any, any,
                where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);
        when(mockDatabase.transaction<void>(any,
                exclusive: anyNamed('exclusive')))
            .thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0]
              as Future<void> Function(Transaction);
          return callback(mockTxn).then<Null>((_) => null);
        });

        await service.ensureLocalUuids();

        verify(mockTxn.update(
          'race_participants',
          any,
          where: 'race_id = ? AND runner_id = ?',
          whereArgs: [10, 20],
        )).called(1);
      });

      test('skips UUID assignment for race_participants when all rows have UUIDs',
          () async {
        _stubSchemaExists(mockDatabase);

        when(mockDatabase.query(
          any,
          columns: anyNamed('columns'),
          where: anyNamed('where'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => []);

        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 0);
        when(mockDatabase.rawUpdate(any)).thenAnswer((_) async => 0);

        await service.ensureLocalUuids();

        // No transaction should be started when there are no null-uuid rows
        verifyNever(mockDatabase.transaction<void>(any,
            exclusive: anyNamed('exclusive')));
      });
    });

    // -------------------------------------------------------------------------
    group('_pushRaceParticipants', () {
      setUp(() {
        _stubSchemaExists(mockDatabase);
        when(mockAuth.currentUserId).thenReturn('user-1');
      });

      test('skips row and clears dirty flag when remote is newer (LWW)', () async {
        const uuid = 'rp-uuid-1';
        const raceUuid = 'race-uuid-1';
        const runnerUuid = 'runner-uuid-1';

        // Dirty local row (older timestamp)
        when(mockDatabase.query(
          'race_participants',
          where: anyNamed('where'),
        )).thenAnswer((_) async => [
              {
                'race_id': 1,
                'runner_id': 2,
                'team_id': 3,
                'uuid': uuid,
                'race_uuid': raceUuid,
                'runner_uuid': runnerUuid,
                'team_uuid': 'team-uuid-1',
                'updated_at': '2024-01-01T00:00:00.000Z',
                'created_at': '2024-01-01T00:00:00.000Z',
                'is_dirty': 1,
              }
            ]);

        // Other tables return no dirty rows
        when(mockDatabase.query(
          argThat(isNot('race_participants')),
          where: anyNamed('where'),
        )).thenAnswer((_) async => []);

        when(mockSyncClient.fetchByUuids(any, any))
            .thenAnswer((_) async => []);

        // Remote row is newer
        when(mockSyncClient.fetchByUuids('race_participants', [uuid]))
            .thenAnswer((_) async => [
                  {
                    'uuid': uuid,
                    'race_uuid': raceUuid,
                    'runner_uuid': runnerUuid,
                    'updated_at': '2024-12-01T00:00:00.000Z',
                  }
                ]);

        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 1);

        await service.pushAll();

        // Should NOT upsert to remote
        verifyNever(mockSyncClient.upsertRows(
          'race_participants',
          any,
          onConflict: anyNamed('onConflict'),
        ));

        // Should clear the dirty flag via rawUpdate
        verify(mockDatabase.rawUpdate(
          'UPDATE race_participants SET is_dirty = 0 WHERE uuid = ?',
          [uuid],
        )).called(1);
      });

      test('pushes row and clears dirty flag when local is newer', () async {
        const uuid = 'rp-uuid-2';
        const raceUuid = 'race-uuid-2';
        const runnerUuid = 'runner-uuid-2';

        when(mockDatabase.query(
          'race_participants',
          where: anyNamed('where'),
        )).thenAnswer((_) async => [
              {
                'race_id': 1,
                'runner_id': 2,
                'team_id': 3,
                'uuid': uuid,
                'race_uuid': raceUuid,
                'runner_uuid': runnerUuid,
                'team_uuid': 'team-uuid-2',
                'updated_at': '2024-12-01T00:00:00.000Z',
                'created_at': '2024-01-01T00:00:00.000Z',
                'is_dirty': 1,
              }
            ]);

        when(mockDatabase.query(
          argThat(isNot('race_participants')),
          where: anyNamed('where'),
        )).thenAnswer((_) async => []);

        when(mockSyncClient.fetchByUuids(any, any))
            .thenAnswer((_) async => []);

        // Remote row is older
        when(mockSyncClient.fetchByUuids('race_participants', [uuid]))
            .thenAnswer((_) async => [
                  {
                    'uuid': uuid,
                    'race_uuid': raceUuid,
                    'runner_uuid': runnerUuid,
                    'updated_at': '2024-01-01T00:00:00.000Z',
                  }
                ]);

        when(mockSyncClient.upsertRows(any, any,
                onConflict: anyNamed('onConflict')))
            .thenAnswer((_) async {});
        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 1);

        await service.pushAll();

        verify(mockSyncClient.upsertRows(
          'race_participants',
          argThat(isA<List>()),
          onConflict: 'race_uuid,runner_uuid',
        )).called(1);

        // Dirty flag cleared via uuid-based rawUpdate
        verify(mockDatabase.rawUpdate(
          argThat(contains('is_dirty = 0')),
          argThat(contains(uuid)),
        )).called(1);
      });
    });

    // -------------------------------------------------------------------------
    group('syncEvents stream', () {
      test('exposes a broadcast stream', () {
        expect(service.syncEvents.isBroadcast, isTrue);
      });

      test('does not emit before pullAll is called', () async {
        final events = <SyncEvent>[];
        final sub = service.syncEvents.listen(events.add);

        expect(events, isEmpty);

        await sub.cancel();
      });
    });
  });
  });
}
