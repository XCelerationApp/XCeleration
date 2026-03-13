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
        when(mockSyncClient.fetchByUuids(any, any))
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

        when(mockDatabase.update(any, any,
                where: anyNamed('where'), whereArgs: anyNamed('whereArgs')))
            .thenAnswer((_) async => 1);
        when(mockDatabase.rawUpdate(any, any)).thenAnswer((_) async => 0);
        when(mockDatabase.rawUpdate(any)).thenAnswer((_) async => 0);

        await service.ensureLocalUuids();

        final captured = verify(mockDatabase.update(
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        verifyNever(mockDatabase.update(
          'runners',
          any,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        ));
      });

      test('preserves is_dirty flag when local is dirty and time diff < 5 min',
          () async {
        const uuid = 'uuid-runner-1';
        // Remote is 2 minutes newer than local — within the 5-minute window
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => [localRow]);

        await service.pullAll();

        final captured = verify(mockDatabase.update(
          'runners',
          captureAny,
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).captured;

        final updated = captured.first as Map<String, dynamic>;
        expect(updated['is_dirty'], 1,
            reason: 'dirty flag must be preserved when diff < 5 minutes');
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
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

        when(mockDatabase.query(
          'runners',
          where: anyNamed('where'),
          whereArgs: anyNamed('whereArgs'),
        )).thenAnswer((_) async => []);

        // Use expectLater so the stream subscription is active before pullAll runs.
        final streamExpectation = expectLater(
          service.syncEvents,
          emits(isA<SyncEvent>().having(
              (e) => e.changedTables, 'changedTables', contains('runners'))),
        );

        await service.pullAll();
        await streamExpectation;
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
}
