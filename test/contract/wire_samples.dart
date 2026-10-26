import 'package:flutter/material.dart' show Color;
import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/core/utils/data_package.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/coach/share_race/services/race_share_service.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

/// Sample data for everything one phone sends another, used to save each
/// release's formats (test/fixtures/wire/(version)/) and to check today's
/// code still sends and reads them. See test/fixtures/wire/README.md.

final sampleRace = RaceRecord(
  raceId: 12,
  date: DateTime.utc(2026, 9, 12, 9),
  name: 'Saturday Invitational',
  type: 'race',
);

final sampleRoster = [
  BibDatum(
    bib: '101',
    name: 'Ava Lee',
    teamAbbreviation: 'NHS',
    grade: '11',
    teamColor: const Color(0xFF1976D2),
  ),
  BibDatum(
    bib: '102',
    name: 'Mia Chen',
    teamAbbreviation: 'RHS',
    grade: '9',
    teamColor: const Color(0xFFD32F2F),
  ),
  // A bib that starts with 0 must stay "007", not become 7.
  BibDatum(bib: '007', name: 'Zoe Park', teamAbbreviation: 'NHS', grade: '12'),
];

/// What a Timer sends back: plain times, a batch with an extra tap, one
/// with a missed runner, and the closing checkpoint.
final sampleTimes = [
  TimingDatum(time: '15:04.11'),
  TimingDatum(time: '15:05.36'),
  TimingDatum(time: '15:05.90'),
  TimingDatum(
    time: '15:05.90',
    conflict: Conflict(type: ConflictType.extraTime, offBy: 1),
  ),
  TimingDatum(time: '15:30.02'),
  TimingDatum(
    time: '15:30.02',
    conflict: Conflict(type: ConflictType.missingTime, offBy: 1),
  ),
  TimingDatum(time: '16:02.50'),
  TimingDatum(
    time: '16:10.00',
    conflict: Conflict(type: ConflictType.confirmRunner, offBy: 1),
  ),
];

/// What a Bib Recorder sends back: bibs in finish order.
final sampleBibsBack = [
  BibDatum(bib: '102', name: 'Mia Chen', teamAbbreviation: 'RHS', grade: '9'),
  BibDatum(bib: '101', name: 'Ava Lee', teamAbbreviation: 'NHS', grade: '11'),
  BibDatum(bib: '007', name: 'Zoe Park', teamAbbreviation: 'NHS', grade: '12'),
];

final sampleResultsRace = Race(
  uuid: 'r-uuid-1',
  raceName: 'Saturday Invitational',
  raceDate: DateTime.utc(2026, 9, 12),
  location: 'Golden Gate Park',
  distance: 5.0,
  distanceUnit: 'km',
  flowState: Race.FLOW_FINISHED,
);

final _nhs = Team(name: 'Northgate', abbreviation: 'NHS');
final _rhs = Team(name: 'Redwood', abbreviation: 'RHS');

final sampleResults = [
  RaceResult(
    place: 1,
    runner: Runner(name: 'Mia Chen', bibNumber: '102', grade: 9),
    team: _rhs,
    finishTime: const Duration(minutes: 15, seconds: 4, milliseconds: 110),
  ),
  RaceResult(
    place: 2,
    runner: Runner(name: 'Ava Lee', bibNumber: '101', grade: 11),
    team: _nhs,
    finishTime: const Duration(minutes: 15, seconds: 5, milliseconds: 360),
  ),
  RaceResult(
    place: 3,
    runner: Runner(name: 'Zoe Park', bibNumber: '007', grade: 12),
    team: _nhs,
    finishTime: const Duration(minutes: 16, seconds: 2, milliseconds: 500),
  ),
];

final samplePackets = [
  Package(number: 1, type: 'DATA', data: 'first chunk'),
  Package(number: 1, type: 'ACK'),
  Package(number: 2, type: 'FIN'),
];

/// Each saved format, by file name, as today's code makes it.
Future<Map<String, String>> currentWireFormats() async {
  final race = sampleRace.encode();
  final times = await TimingEncodeUtils.encodeTimeRecords(sampleTimes);
  return {
    'race_to_timer.txt': race,
    'race_to_bib_recorder.txt':
        '$race---${await BibEncodeUtils.getEncodedBibData(sampleRoster)}',
    'times_to_coach.txt': times,
    'bibs_to_coach.txt': await BibEncodeUtils.getEncodedBibData(sampleBibsBack),
    'results_to_spectators.txt': RaceShareService.preparePayloadFromData(
      race: sampleResultsRace,
      results: sampleResults,
    ),
    'packets.txt': samplePackets.map((p) => p.toString()).join('\n'),
  };
}
