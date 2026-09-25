import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';

void main() {
  group('TeamParticipant', () {
    group('fromMap', () {
      test('parses all fields correctly', () {
        final map = {
          'race_id': 1,
          'team_id': 2,
          'team_color_override': 0xFF2196F3,
          'created_at': '2024-01-01T00:00:00.000',
          'updated_at': '2024-01-02T00:00:00.000',
          'deleted_at': '2024-01-03T00:00:00.000',
          'is_dirty': 1,
        };

        final participant = TeamParticipant.fromMap(map);

        expect(participant.raceId, 1);
        expect(participant.teamId, 2);
        expect(participant.colorOverride, 0xFF2196F3);
        expect(participant.createdAt, DateTime.parse('2024-01-01T00:00:00.000'));
        expect(participant.updatedAt, DateTime.parse('2024-01-02T00:00:00.000'));
        expect(participant.deletedAt, DateTime.parse('2024-01-03T00:00:00.000'));
        expect(participant.isDirty, 1);
      });

      test('handles null optional fields', () {
        final map = {
          'race_id': 1,
          'team_id': 2,
          'team_color_override': null,
          'created_at': null,
          'updated_at': null,
          'deleted_at': null,
          'is_dirty': null,
        };

        final participant = TeamParticipant.fromMap(map);

        expect(participant.colorOverride, isNull);
        expect(participant.createdAt, isNull);
        expect(participant.updatedAt, isNull);
        expect(participant.deletedAt, isNull);
        expect(participant.isDirty, isNull);
      });
    });

    group('toMap', () {
      test('serializes all non-null fields correctly', () {
        final createdAt = DateTime(2024, 1, 1);
        final deletedAt = DateTime(2024, 1, 3);
        final participant = TeamParticipant(
          raceId: 1,
          teamId: 2,
          colorOverride: 0xFF2196F3,
          createdAt: createdAt,
          deletedAt: deletedAt,
          isDirty: 0,
        );

        final map = participant.toMap();

        expect(map['race_id'], 1);
        expect(map['team_id'], 2);
        expect(map['team_color_override'], 0xFF2196F3);
        expect(map['created_at'], createdAt.toIso8601String());
        expect(map['deleted_at'], deletedAt.toIso8601String());
        expect(map['is_dirty'], 0);
      });

      test('serializes null optional fields as null', () {
        final participant = TeamParticipant(raceId: 1, teamId: 2);

        final map = participant.toMap();

        expect(map['team_color_override'], isNull);
        expect(map['created_at'], isNull);
        expect(map['deleted_at'], isNull);
        expect(map['is_dirty'], isNull);
      });

      test('always writes updated_at as a non-null ISO string', () {
        final participant = TeamParticipant(raceId: 1, teamId: 2);

        final map = participant.toMap();

        expect(map['updated_at'], isNotNull);
        expect(() => DateTime.parse(map['updated_at'] as String), returnsNormally);
      });
    });

    group('fromMap / toMap round-trip', () {
      test('preserves raceId, teamId, colorOverride, isDirty', () {
        final map = {
          'race_id': 3,
          'team_id': 7,
          'team_color_override': 0xFFFF0000,
          'created_at': null,
          'updated_at': null,
          'deleted_at': null,
          'is_dirty': 0,
        };

        final result = TeamParticipant.fromMap(map).toMap();

        expect(result['race_id'], 3);
        expect(result['team_id'], 7);
        expect(result['team_color_override'], 0xFFFF0000);
        expect(result['is_dirty'], 0);
      });
    });

    group('isValid', () {
      test('returns true when raceId and teamId are positive', () {
        expect(TeamParticipant(raceId: 1, teamId: 1).isValid, isTrue);
      });

      test('returns false when raceId is null', () {
        expect(TeamParticipant(teamId: 1).isValid, isFalse);
      });

      test('returns false when teamId is null', () {
        expect(TeamParticipant(raceId: 1).isValid, isFalse);
      });

      test('returns false when raceId is 0', () {
        expect(TeamParticipant(raceId: 0, teamId: 1).isValid, isFalse);
      });

      test('returns false when teamId is 0', () {
        expect(TeamParticipant(raceId: 1, teamId: 0).isValid, isFalse);
      });
    });

    group('copyWith', () {
      test('returns a new instance with replaced fields', () {
        const original = TeamParticipant(raceId: 1, teamId: 2, isDirty: 0);

        final copy = original.copyWith(teamId: 99, isDirty: 1);

        expect(copy.raceId, 1);
        expect(copy.teamId, 99);
        expect(copy.isDirty, 1);
      });

      test('preserves unchanged fields', () {
        const original = TeamParticipant(raceId: 1, teamId: 2, colorOverride: 0xFFFF0000);

        final copy = original.copyWith(raceId: 5);

        expect(copy.colorOverride, 0xFFFF0000);
        expect(copy.teamId, 2);
      });
    });

    group('equality', () {
      test('two instances with same raceId, teamId, colorOverride are equal', () {
        const a = TeamParticipant(raceId: 1, teamId: 2, colorOverride: 0xFF0000FF);
        const b = TeamParticipant(raceId: 1, teamId: 2, colorOverride: 0xFF0000FF);
        expect(a, equals(b));
      });

      test('instances with different raceId are not equal', () {
        const a = TeamParticipant(raceId: 1, teamId: 2);
        const b = TeamParticipant(raceId: 3, teamId: 2);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
