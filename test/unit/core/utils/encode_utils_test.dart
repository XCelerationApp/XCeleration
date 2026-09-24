import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/decode_utils.dart';
import 'package:xceleration/core/utils/encode_utils.dart';
import 'package:xceleration/shared/models/database/base_models.dart';

import '../../coach/flows/post_race_flow/load_results_controller_test.mocks.dart';

void main() {
  test('sharing the roster skips a participant whose runner is missing', () async {
    // It used to return '' for that participant and then fail on the cast.
    final race = MockMasterRace();
    const kept = RaceParticipant(raceId: 1, runnerId: 1, teamId: 1);
    const orphan = RaceParticipant(raceId: 1, runnerId: 2, teamId: 1);
    when(race.raceParticipants).thenAnswer((_) async => [kept, orphan]);
    when(race.getRaceRunnerFromRaceParticipant(kept)).thenAnswer((_) async =>
        RaceRunner(
          raceId: 1,
          runner: const Runner(runnerId: 1, name: 'A', bibNumber: '1', grade: 11),
          team: const Team(teamId: 1, name: 'Eagles', abbreviation: 'EAG'),
        ));
    when(race.getRaceRunnerFromRaceParticipant(orphan))
        .thenAnswer((_) async => null);

    final encoded = await BibEncodeUtils.getEncodedRunnersBibData(race);
    final decoded = await BibDecodeUtils.decodeEncodedRunners(encoded);

    expect([for (final b in (decoded as Success).value) b.bib], ['1']);
  });
}
