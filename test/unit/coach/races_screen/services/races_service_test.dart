import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/races_screen/services/races_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/i_database_helper.dart';
import 'package:xceleration/shared/models/database/race.dart';

@GenerateMocks([IDatabaseHelper])
import 'races_service_test.mocks.dart';

void main() {
  late RacesService service;
  late MockIDatabaseHelper mockDb;

  setUp(() {
    mockDb = MockIDatabaseHelper();
    service = RacesService(db: mockDb, currentUserId: () => 'user-123');
  });

  // =========================================================================
  group('RacesService', () {
    // -----------------------------------------------------------------------
    group('loadRaces', () {
      test('returns Success with races when database query succeeds', () async {
        final races = [
          Race(raceId: 1, raceName: 'State Meet'),
          Race(raceId: 2, raceName: 'Invitational'),
        ];
        when(mockDb.getAllRaces()).thenAnswer((_) async => races);

        final result = await service.loadRaces();

        expect(result, isA<Success<List<Race>>>());
        expect((result as Success).value, equals(races));
      });

      test('returns Failure when database throws', () async {
        when(mockDb.getAllRaces()).thenThrow(Exception('db error'));

        final result = await service.loadRaces();

        expect(result, isA<Failure<List<Race>>>());
        expect((result as Failure).error.userMessage,
            'Could not load races. Please try again.');
      });

      test('Failure wraps the original exception', () async {
        final exception = Exception('connection lost');
        when(mockDb.getAllRaces()).thenThrow(exception);

        final result = await service.loadRaces();

        expect((result as Failure).error.originalException, exception);
      });
    });

    // -----------------------------------------------------------------------
    group('createRace', () {
      final race = Race(raceId: 0, raceName: 'Spring Classic');

      test('stamps owner and returns Success with new race ID', () async {
        when(mockDb.createRace(any)).thenAnswer((_) async => 42);

        final result = await service.createRace(race);

        expect(result, isA<Success<int>>());
        expect((result as Success).value, 42);

        final captured =
            verify(mockDb.createRace(captureAny)).captured.single as Race;
        expect(captured.ownerUserId, 'user-123');
      });

      test('stamps null owner when currentUserId returns null', () async {
        final serviceNoOwner =
            RacesService(db: mockDb, currentUserId: () => null);
        when(mockDb.createRace(any)).thenAnswer((_) async => 7);

        await serviceNoOwner.createRace(race);

        final captured =
            verify(mockDb.createRace(captureAny)).captured.single as Race;
        expect(captured.ownerUserId, isNull);
      });

      test('returns Failure when database throws', () async {
        when(mockDb.createRace(any)).thenThrow(Exception('insert failed'));

        final result = await service.createRace(race);

        expect(result, isA<Failure<int>>());
        expect((result as Failure).error.userMessage,
            'Could not create race. Please try again.');
      });

      test('Failure wraps the original exception', () async {
        final exception = Exception('disk full');
        when(mockDb.createRace(any)).thenThrow(exception);

        final result = await service.createRace(race);

        expect((result as Failure).error.originalException, exception);
      });
    });

    // -----------------------------------------------------------------------
    group('deleteRace', () {
      test('returns Success when database deletes successfully', () async {
        when(mockDb.deleteRace(1)).thenAnswer((_) async {});

        final result = await service.deleteRace(1);

        expect(result, isA<Success<void>>());
        verify(mockDb.deleteRace(1)).called(1);
      });

      test('returns Failure when database throws', () async {
        when(mockDb.deleteRace(1)).thenThrow(Exception('delete failed'));

        final result = await service.deleteRace(1);

        expect(result, isA<Failure<void>>());
        expect((result as Failure).error.userMessage,
            'Could not delete race. Please try again.');
      });

      test('Failure wraps the original exception', () async {
        final exception = Exception('foreign key constraint');
        when(mockDb.deleteRace(1)).thenThrow(exception);

        final result = await service.deleteRace(1);

        expect((result as Failure).error.originalException, exception);
      });
    });
  });
}
