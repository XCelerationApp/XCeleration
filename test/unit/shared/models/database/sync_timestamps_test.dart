import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';

/// Every synced model stamps `updated_at` in toMap(). Supabase reads an
/// offset-less timestamp as UTC, so the stamp must carry an explicit `Z`.
void main() {
  final models = <String, Map<String, dynamic> Function()>{
    'Runner': () => const Runner().toMap(),
    'Team': () => const Team().toMap(),
    'Race': () => Race().toMap(),
    'RaceResult': () => RaceResult().toMap(),
    'RaceParticipant': () => const RaceParticipant().toMap(),
    'TeamParticipant': () => const TeamParticipant().toMap(),
  };

  group('toMap updated_at', () {
    models.forEach((name, toMap) {
      test('$name writes updated_at in UTC', () {
        expect(toMap()['updated_at'], endsWith('Z'));
      });
    });
  });
}
