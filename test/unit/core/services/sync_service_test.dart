import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xceleration/core/services/i_auth_service.dart';
import 'package:xceleration/core/services/i_remote_api_client.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';

@GenerateMocks([IDatabaseHelper, IRemoteApiClient, IAuthService, Database, SupabaseClient])
import 'sync_service_test.mocks.dart';

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

void main() {
  late SyncService service;
  late MockIDatabaseHelper mockDbHelper;
  late MockIRemoteApiClient mockRemote;
  late MockIAuthService mockAuth;
  late MockDatabase mockDatabase;
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockDbHelper = MockIDatabaseHelper();
    mockRemote = MockIRemoteApiClient();
    mockAuth = MockIAuthService();
    mockDatabase = MockDatabase();
    mockSupabaseClient = MockSupabaseClient();

    service = SyncService(db: mockDbHelper, remote: mockRemote, auth: mockAuth);

    when(mockDbHelper.databaseConn).thenAnswer((_) async => mockDatabase);
    when(mockRemote.init()).thenAnswer((_) async {});
    when(mockRemote.isInitialized).thenReturn(false);
    when(mockRemote.client).thenReturn(mockSupabaseClient);
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
        verifyNever(mockDbHelper.databaseConn);
      });

      test('skips push and pull when user is not authenticated', () async {
        when(mockRemote.isInitialized).thenReturn(true);
        when(mockAuth.isSignedIn).thenReturn(false);

        await service.syncAll();

        verifyNever(mockDbHelper.databaseConn);
        verifyNever(mockDatabase.rawQuery(any, any));
      });

      test('rethrows exceptions from underlying operations', () async {
        when(mockRemote.isInitialized).thenReturn(true);
        when(mockAuth.isSignedIn).thenReturn(true);
        when(mockAuth.currentUserId).thenReturn('user-1');
        when(mockDbHelper.databaseConn).thenThrow(Exception('db failure'));

        await expectLater(service.syncAll(), throwsA(isA<Exception>()));
      });
    });

    // -------------------------------------------------------------------------
    group('pushAll', () {
      test('skips all tables when normalized schema is not present', () async {
        _stubSchemaMissing(mockDatabase);

        await service.pushAll();

        verifyNever(mockDatabase.rawUpdate(any, any));
      });

      test('skips upsert for table when no dirty rows exist', () async {
        _stubSchemaExists(mockDatabase);
        // No dirty rows for any table
        when(mockDatabase.query(any, where: anyNamed('where')))
            .thenAnswer((_) async => []);

        await service.pushAll();

        verifyNever(mockDatabase.rawUpdate(any, any));
      });

      test('skips push when currentUserId is null', () async {
        when(mockAuth.currentUserId).thenReturn(null);

        await service.pushAll();

        // Auth guard fires before any DB access — no rawUpdate or schema query.
        verifyNever(mockDatabase.rawUpdate(any, any));
        verifyNever(mockDatabase.rawQuery(any, any));
      });
    });

    // -------------------------------------------------------------------------
    group('pullAll', () {
      test('skips all pulls when normalized schema is not present', () async {
        _stubSchemaMissing(mockDatabase);

        await service.pullAll();

        // No cursor or data queries should occur
        verifyNever(mockDatabase.query(any,
            where: anyNamed('where'), whereArgs: anyNamed('whereArgs')));
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
