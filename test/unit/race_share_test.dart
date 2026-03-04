import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/share_race/services/race_share_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/race_share_decoder.dart';
import 'package:xceleration/shared/models/database/race.dart';
import 'package:xceleration/shared/models/database/race_result.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

void main() {
  group('Race share encode/decode', () {
    test('preparePayloadFromData produces compact base64+gzip V2 payload', () {
      final race = Race(
        uuid: 'r-uuid',
        raceName: 'Test Meet',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'Somewhere',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );

      final team = Team(name: 'Wildcats', abbreviation: 'WIL');
      final results = <RaceResult>[
        RaceResult(
          place: 1,
          runner: Runner(name: 'Alice', bibNumber: '100', grade: 12),
          team: team,
          finishTime: const Duration(minutes: 18, seconds: 5, milliseconds: 30),
        ),
        RaceResult(
          place: 2,
          runner: Runner(name: 'Bob', bibNumber: '101', grade: 12),
          team: team,
          finishTime:
              const Duration(minutes: 18, seconds: 45, milliseconds: 10),
        ),
      ];

      final encoded = RaceShareService.preparePayloadFromData(
        race: race,
        results: results,
      );
      // Decode for verification
      final decodedJson = utf8.decode(gzip.decode(base64Decode(encoded)));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;
      expect(map['type'], 'RACE_SHARE_V2');
      expect(map['race']['name'], 'Test Meet');
      expect((map['r'] as List).length, 2);
      expect(map['r'][0][0], 1); // place
      expect(map['r'][0][1], 'Alice'); // name
      expect(map['r'][0][3], 18 * 60 * 1000 + 5 * 1000 + 30); // finish ms
    });

    test('decodeToResultsData returns Success with reconstructed data', () {
      final race = Race(
        uuid: 'r-uuid',
        raceName: 'Preview Race',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'Park',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );
      final team = Team(name: 'Hawks', abbreviation: 'HAW');
      final results = <RaceResult>[
        RaceResult(
          place: 1,
          runner: Runner(name: 'Eve', bibNumber: '200', grade: 11),
          team: team,
          finishTime: const Duration(minutes: 19, seconds: 10),
        ),
        RaceResult(
          place: 2,
          runner: Runner(name: 'Dan', bibNumber: '201', grade: 10),
          team: team,
          finishTime: const Duration(minutes: 19, seconds: 50),
        ),
      ];

      final payload = RaceShareService.preparePayloadFromData(
        race: race,
        results: results,
      );

      final result = RaceShareDecoder.decodeToResultsData(payload);
      expect(result, isA<Success<RaceShareDecodedData>>());
      final decoded = (result as Success<RaceShareDecodedData>).value;
      expect(decoded.title.contains('Preview Race'), isTrue);
      expect(decoded.results.individualResults.length, 2);
      expect(decoded.results.individualResults.first.name, 'Eve');
      expect(decoded.results.overallTeamResults.isNotEmpty, isTrue);
    });

    test('decodeToResultsData returns Failure for invalid payload', () {
      final result =
          RaceShareDecoder.decodeToResultsData('not-valid-base64!!!');
      expect(result, isA<Failure<RaceShareDecodedData>>());
      final error = (result as Failure<RaceShareDecodedData>).error;
      expect(error.userMessage, isNotEmpty);
      expect(error.originalException, isNotNull);
    });

    test('decodeToResultsData returns Failure for unsupported payload type',
        () {
      // Build a valid base64+gzip payload with wrong type field
      final json = jsonEncode({'type': 'RACE_SHARE_V1', 'race': {}, 'r': []});
      final encoded = base64Encode(gzip.encode(utf8.encode(json)));

      final result = RaceShareDecoder.decodeToResultsData(encoded);
      expect(result, isA<Failure<RaceShareDecodedData>>());
    });

    test('decodeWithRaw returns Success with rawEncoded preserved', () {
      final race = Race(
        uuid: 'r-uuid',
        raceName: 'Test Race',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'Track',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );
      final team = Team(name: 'Tigers', abbreviation: 'TIG');
      final raceResults = <RaceResult>[
        RaceResult(
          place: 1,
          runner: Runner(name: 'Sam', bibNumber: '300', grade: 11),
          team: team,
          finishTime: const Duration(minutes: 20, seconds: 0),
        ),
      ];

      final payload = RaceShareService.preparePayloadFromData(
        race: race,
        results: raceResults,
      );

      final result = RaceShareDecoder.decodeWithRaw(payload);
      expect(result, isA<Success>());
      final value = (result as Success).value;
      expect(value.rawEncoded, equals(payload));
      expect(value.results.individualResults.length, 1);
    });

    test('decodeWithRaw returns Failure for invalid payload', () {
      final result = RaceShareDecoder.decodeWithRaw('garbage');
      expect(result, isA<Failure>());
      final error = (result as Failure).error;
      expect(error.userMessage, isNotEmpty);
    });

    test('encode/decode 75 runners and print lengths', () {
      final race = Race(
        uuid: 'r-uuid-75',
        raceName: 'Big Race',
        raceDate: DateTime.utc(2025, 9, 23),
        location: 'XC Course',
        distance: 5.0,
        distanceUnit: 'mi',
        flowState: Race.FLOW_FINISHED,
      );

      final teams = [
        Team(name: 'Hawks', abbreviation: 'HAW'),
        Team(name: 'Wolves', abbreviation: 'WOL'),
        Team(name: 'Bears', abbreviation: 'BEA'),
      ];

      final List<RaceResult> results = [];
      for (int i = 0; i < 75; i++) {
        final team = teams[i % teams.length];
        results.add(RaceResult(
          place: i + 1,
          runner: Runner(
              name: 'Runner ${i + 1}',
              bibNumber: 'B${i + 1}',
              grade: 9 + (i % 4)),
          team: team,
          finishTime: Duration(minutes: 18 + (i ~/ 10), seconds: (i * 3) % 60),
        ));
      }

      final encoded = RaceShareService.preparePayloadFromData(
        race: race,
        results: results,
      );

      // Verify decode works
      final result = RaceShareDecoder.decodeToResultsData(encoded);
      expect(result, isA<Success<RaceShareDecodedData>>());
      final decoded = (result as Success<RaceShareDecodedData>).value;
      expect(decoded.results.individualResults.length, 75);

      // Print character lengths
      final compressedLen = encoded.length;
      final plainJsonLen =
          utf8.decode(gzip.decode(base64Decode(encoded))).length;
      Logger.d(
          'RaceShare lengths — compressed(base64): $compressedLen chars, json: $plainJsonLen chars');
    });
  });
}
