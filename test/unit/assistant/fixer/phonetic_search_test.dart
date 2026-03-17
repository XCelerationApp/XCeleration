import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/services/phonetic_search.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';

Runner _runner({String bib = '0', String? name}) => Runner(
      raceId: 1,
      bibNumber: bib,
      name: name,
      createdAt: DateTime(2026),
    );

void main() {
  group('PhoneticSearch', () {
    group('soundex', () {
      test('encodes Robert as R163', () {
        expect(PhoneticSearch.soundex('Robert'), 'R163');
      });

      test('encodes Rupert as R163 — same as Robert', () {
        expect(PhoneticSearch.soundex('Rupert'), 'R163');
      });

      test('encodes Johnson as J525', () {
        expect(PhoneticSearch.soundex('Johnson'), 'J525');
      });

      test('encodes Jonson as J525 — same as Johnson', () {
        expect(PhoneticSearch.soundex('Jonson'), 'J525');
      });

      test('pads short names to 4 characters', () {
        expect(PhoneticSearch.soundex('Lee'), 'L000');
      });

      test('returns empty string for empty input', () {
        expect(PhoneticSearch.soundex(''), '');
      });

      test('ignores non-alphabetic characters', () {
        expect(PhoneticSearch.soundex('O\'Brien'), PhoneticSearch.soundex('OBrien'));
      });
    });

    group('score', () {
      test('returns 1.0 for exact bib match', () {
        final runner = _runner(bib: '105');
        expect(PhoneticSearch.score('105', runner), 1.0);
      });

      test('returns 0.8 for bib substring match', () {
        final runner = _runner(bib: '1051');
        expect(PhoneticSearch.score('105', runner), 0.8);
      });

      test('returns 0.9 for exact name match', () {
        final runner = _runner(name: 'Alex Johnson');
        expect(PhoneticSearch.score('alex johnson', runner), 0.9);
      });

      test('returns 0.8 when query is substring of name', () {
        final runner = _runner(name: 'Alex Johnson');
        expect(PhoneticSearch.score('Johnson', runner), 0.8);
      });

      test('returns 0.5 when query tokens are substrings of name tokens but full query is not in name', () {
        // 'Alex Thomp' as a string is not in 'Alexander Thompson',
        // but 'alex' is a prefix of 'alexander' and 'thomp' of 'thompson'.
        final runner = _runner(name: 'Alexander Thompson');
        expect(PhoneticSearch.score('Alex Thomp', runner), 0.5);
      });

      test('returns 0.4 for phonetic (Soundex) match — Jonson → Johnson', () {
        final runner = _runner(name: 'Alex Johnson');
        expect(PhoneticSearch.score('Jonson', runner), 0.4);
      });

      test('returns 0.4 for phonetic match — Smyth → Smith', () {
        final runner = _runner(name: 'Ryan Smith');
        expect(PhoneticSearch.score('Smyth', runner), 0.4);
      });

      test('returns 0 for blank query', () {
        final runner = _runner(name: 'Alex Johnson');
        expect(PhoneticSearch.score('', runner), 0);
        expect(PhoneticSearch.score('   ', runner), 0);
      });

      test('returns 0 when nothing matches', () {
        final runner = _runner(bib: '999', name: 'Alex Johnson');
        expect(PhoneticSearch.score('Zzzzz', runner), 0);
      });

      test('returns 0 for runner with no name when query is not a bib match', () {
        final runner = _runner(bib: '105');
        expect(PhoneticSearch.score('Johnson', runner), 0);
      });
    });

    group('FixerController.search integration', () {
      // Verify that the scoring correctly ranks a phonetic near-match above a
      // non-match, using PhoneticSearch directly (controller uses same logic).
      test('phonetic match ranks above zero', () {
        final runners = [
          _runner(bib: '101', name: 'Jordan Lee'),
          _runner(bib: '102', name: 'Alex Johnson'),
          _runner(bib: '103', name: 'Sarah Kim'),
        ];

        final scored = runners
            .map((r) => (runner: r, score: PhoneticSearch.score('Jonson', r)))
            .where((e) => e.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

        expect(scored.length, 1);
        expect(scored.first.runner.name, 'Alex Johnson');
      });

      test('substring match ranks above phonetic match', () {
        final runners = [
          _runner(bib: '101', name: 'Johnson City Runner'),
          _runner(bib: '102', name: 'Alex Jonson'),
        ];

        final scored = runners
            .map((r) => (runner: r, score: PhoneticSearch.score('Johnson', r)))
            .where((e) => e.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

        expect(scored.first.runner.name, 'Johnson City Runner');
      });
    });
  });
}
