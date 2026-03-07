import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/coach/races_screen/services/races_service.dart';
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
      test('returns races from database', () async {
        final races = [
          Race(raceId: 1, raceName: 'State Meet'),
          Race(raceId: 2, raceName: 'Invitational'),
        ];
        when(mockDb.getAllRaces()).thenAnswer((_) async => races);

        final result = await service.loadRaces();

        expect(result, equals(races));
      });

      test('propagates exception when database throws', () async {
        when(mockDb.getAllRaces()).thenThrow(Exception('db error'));

        expect(() => service.loadRaces(), throwsA(isA<Exception>()));
      });
    });

    // -----------------------------------------------------------------------
    group('createRace', () {
      final race = Race(raceId: 0, raceName: 'Spring Classic');

      test('stamps owner and returns new race ID', () async {
        when(mockDb.createRace(any)).thenAnswer((_) async => 42);

        final result = await service.createRace(race);

        expect(result, 42);
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

      test('propagates exception when database throws', () async {
        when(mockDb.createRace(any)).thenThrow(Exception('insert failed'));

        expect(() => service.createRace(race), throwsA(isA<Exception>()));
      });
    });

    // -----------------------------------------------------------------------
    group('deleteRace', () {
      test('calls database delete', () async {
        when(mockDb.deleteRace(1)).thenAnswer((_) async {});

        await service.deleteRace(1);

        verify(mockDb.deleteRace(1)).called(1);
      });

      test('propagates exception when database throws', () async {
        when(mockDb.deleteRace(1)).thenThrow(Exception('delete failed'));

        expect(() => service.deleteRace(1), throwsA(isA<Exception>()));
      });
    });

    // -----------------------------------------------------------------------
    group('validateName', () {
      test('returns null when name is non-empty', () {
        expect(service.validateName('State Meet'), isNull);
      });

      test('returns error message when name is empty', () {
        expect(service.validateName(''), isNotNull);
      });
    });

    group('validateLocation', () {
      test('returns null when location is non-empty', () {
        expect(service.validateLocation('Central Park'), isNull);
      });

      test('returns error message when location is empty', () {
        expect(service.validateLocation(''), isNotNull);
      });
    });

    group('validateDate', () {
      test('returns null for a valid date string', () {
        expect(service.validateDate('2024-06-15'), isNull);
      });

      test('returns error when date is empty', () {
        expect(service.validateDate(''), isNotNull);
      });

      test('returns error when date string is not parseable', () {
        expect(service.validateDate('not-a-date'), isNotNull);
      });

      test('returns error when year is before 1900', () {
        expect(service.validateDate('1800-01-01'), isNotNull);
      });
    });

    group('validateDistance', () {
      test('returns null for a positive distance', () {
        expect(service.validateDistance('5.0'), isNull);
      });

      test('returns error when distance is empty', () {
        expect(service.validateDistance(''), isNotNull);
      });

      test('returns error when distance is not a number', () {
        expect(service.validateDistance('abc'), isNotNull);
      });

      test('returns error when distance is zero', () {
        expect(service.validateDistance('0'), isNotNull);
      });

      test('returns error when distance is negative', () {
        expect(service.validateDistance('-1.5'), isNotNull);
      });
    });

    group('getFirstError', () {
      TextEditingController ctrl(String text) =>
          TextEditingController(text: text);

      test('returns null when all fields are valid', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNull);
      });

      test('returns name error when name is empty', () {
        final result = service.getFirstError(
          nameController: ctrl(''),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
        expect(result, contains('name'));
      });

      test('returns location error when location is empty', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl(''),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
        expect(result, contains('location'));
      });

      test('returns date error when date is empty', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl(''),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
        expect(result, contains('date'));
      });

      test('returns date error when date is invalid format', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('bad-date'),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
      });

      test('returns distance error when distance is empty', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl(''),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
        expect(result, contains('distance'));
      });

      test('returns distance error when distance is not a number', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('abc'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
      });

      test('returns distance error when distance is zero or negative', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('0'),
          teamControllers: [ctrl('Team A')],
        );
        expect(result, isNotNull);
      });

      test('returns team error when all team names are blank', () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl(''), ctrl('  ')],
        );
        expect(result, isNotNull);
        expect(result, contains('team'));
      });

      test('ignores blank team entries when at least one team is non-empty',
          () {
        final result = service.getFirstError(
          nameController: ctrl('State Meet'),
          locationController: ctrl('Central Park'),
          dateController: ctrl('2024-06-15'),
          distanceController: ctrl('5.0'),
          teamControllers: [ctrl(''), ctrl('Team A')],
        );
        expect(result, isNull);
      });
    });
  });
}
