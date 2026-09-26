import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/bib_suggestions.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

// A bib the Bib Recorder typed that nobody has: who was it most likely?
// One slip of the thumb away first, then the team whose bibs it falls among.

const _eagles = Team(teamId: 1, name: 'Eagles');
const _owls = Team(teamId: 2, name: 'Owls');

RaceRunner _r(String name, String bib, Team team) => RaceRunner(
      raceId: 1,
      runner: Runner(runnerId: int.parse(bib), name: name, bibNumber: bib),
      team: team,
    );

void main() {
  group('bibSlip', () {
    test('names each kind of slip', () {
      expect(bibSlip('1056', '1055'), 'One digit different');
      expect(bibSlip('1075', '1057'), 'Two digits swapped');
      expect(bibSlip('105', '1055'), 'A digit left out');
      expect(bibSlip('10557', '1055'), 'One digit too many');
    });

    test('is null for more than one slip', () {
      expect(bibSlip('1099', '1055'), isNull);
      expect(bibSlip('5510', '1055'), isNull);
      expect(bibSlip('10', '1055'), isNull);
    });
  });

  group('suggestRunnersForBib', () {
    final blake = _r('Blake', '1055', _eagles);
    final devon = _r('Devon', '1057', _eagles);
    final casey = _r('Casey', '1052', _eagles);
    final umi = _r('Umi', '1074', _owls);
    final roster = [blake, devon, casey, umi, _r('Sage', '1072', _owls)];

    test('puts runners one slip away first, with why', () {
      final s = suggestRunnersForBib('10557',
          free: [blake, devon, casey, umi], roster: roster);

      // An extra 5 either way: it could be Blake (1055) or Devon (1057).
      expect(s.map((x) => x.runner), containsAll([blake, devon]));
      expect(s.map((x) => x.runner), isNot(contains(casey)));
      expect(s.first.reasons, ['One digit too many', 'Not placed yet']);
    });

    test('prefers a slip inside the right team\'s bibs', () {
      // 1073 is one digit from Umi (1074, Owls 1072–1074) and from no Eagle.
      final s = suggestRunnersForBib('1073',
          free: [blake, devon, umi], roster: roster);

      expect(s.first.runner, umi);
      expect(s.first.reasons,
          ['One digit different', 'Among Owls\'s bibs (1072–1074)',
           'Not placed yet']);
    });

    test('falls back to the team whose bibs it falls among', () {
      // 1066 is no single slip from anyone, but falls in the Hawks' block.
      const hawks = Team(teamId: 3, name: 'Hawks');
      final kai = _r('Kai', '1080', hawks);
      final hawksRoster = [_r('Jo', '1060', hawks), kai];
      final s = suggestRunnersForBib('1066',
          free: [kai, umi], roster: [...roster, ...hawksRoster]);

      expect(s.map((x) => x.runner), [kai]);
      expect(s.single.reasons.first, 'Among Hawks\'s bibs (1060–1080)');
    });

    test('only suggests runners not placed yet, and at most three', () {
      final many = [
        for (var i = 0; i < 9; i++) _r('R$i', '10${50 + i}', _eagles),
      ];
      final s = suggestRunnersForBib('1051', free: many, roster: many);

      expect(s.length, 3);
    });

    test('nothing when nothing is close', () {
      expect(
          suggestRunnersForBib('9999', free: [blake, umi], roster: roster),
          isEmpty);
    });
  });
}
