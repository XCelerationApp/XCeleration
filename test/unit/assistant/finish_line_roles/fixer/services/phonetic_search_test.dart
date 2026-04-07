import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/services/phonetic_search.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';

void main() {
  Runner makeRunner(String bib, {String? name}) => Runner(
        raceId: 1,
        bibNumber: bib,
        name: name,
        createdAt: DateTime(2026),
      );

  group('PhoneticSearch', () {
    group('soundex', () {
      test('empty string returns empty', () {
        expect(PhoneticSearch.soundex(''), '');
      });

      test('string with only non-alpha chars returns empty', () {
        expect(PhoneticSearch.soundex('123!@#'), '');
      });

      test('non-alpha chars are stripped before encoding', () {
        expect(
          PhoneticSearch.soundex('h3llo!'),
          PhoneticSearch.soundex('hllo'),
        );
      });

      test('single alphabetic char returns letter + 000', () {
        expect(PhoneticSearch.soundex('a'), 'A000');
        expect(PhoneticSearch.soundex('z'), 'Z000');
      });

      test('result is always 4 characters', () {
        for (final word in ['a', 'hi', 'bob', 'alice', 'christopher']) {
          expect(PhoneticSearch.soundex(word).length, 4);
        }
      });

      test('adjacent same-code characters are suppressed', () {
        // 'bbbb' — all b's share code '1', only first is kept.
        expect(PhoneticSearch.soundex('bbbb'), 'B000');
      });

      test('vowels reset the previous code, allowing repeated consonant groups', () {
        // 'aba' — b=1, a resets prev to 0, then no more consonants.
        expect(PhoneticSearch.soundex('aba'), 'A100');
      });

      test('known soundex: Robert → R163', () {
        expect(PhoneticSearch.soundex('robert'), 'R163');
      });

      test('known soundex: Rupert → R163 (phonetically similar to Robert)', () {
        expect(PhoneticSearch.soundex('rupert'), 'R163');
      });

      test('result is uppercase first letter', () {
        expect(PhoneticSearch.soundex('alice')[0], 'A');
        expect(PhoneticSearch.soundex('ALICE')[0], 'A');
      });
    });

    group('score', () {
      test('blank query returns 0.0', () {
        final runner = makeRunner('105', name: 'Alice');
        expect(PhoneticSearch.score('', runner), 0.0);
        expect(PhoneticSearch.score('   ', runner), 0.0);
      });

      test('exact bib match returns 1.0', () {
        final runner = makeRunner('105', name: 'Alice');
        expect(PhoneticSearch.score('105', runner), 1.0);
      });

      test('exact name match returns 0.9', () {
        final runner = makeRunner('105', name: 'Alice Johnson');
        expect(PhoneticSearch.score('alice johnson', runner), 0.9);
      });

      test('bib substring returns 0.8', () {
        // '10' is a substring of '105'
        final runner = makeRunner('105');
        expect(PhoneticSearch.score('10', runner), 0.8);
      });

      test('name substring returns 0.8', () {
        // 'alice' is a substring of 'alice johnson'
        final runner = makeRunner('999', name: 'Alice Johnson');
        expect(PhoneticSearch.score('alice', runner), 0.8);
      });

      test('token substring returns 0.5', () {
        // 'ali smi' is NOT a full substring of 'alice johnson',
        // but token 'ali' IS a substring of name token 'alice'.
        final runner = makeRunner('999', name: 'Alice Johnson');
        expect(PhoneticSearch.score('ali smi', runner), 0.5);
      });

      test('phonetic match returns 0.4', () {
        // soundex('robert') == soundex('rupert') == R163
        final runner = makeRunner('200', name: 'Rupert Ryan');
        expect(PhoneticSearch.score('robert', runner), 0.4);
      });

      test('no match returns 0.0', () {
        // 'xyz' doesn't match bib '200' or name 'Alice Johnson' by any signal.
        final runner = makeRunner('200', name: 'Alice Johnson');
        expect(PhoneticSearch.score('xyz', runner), 0.0);
      });

      test('returns 0 when name is null and no bib match', () {
        final runner = makeRunner('200'); // no name
        expect(PhoneticSearch.score('alice', runner), 0.0);
      });

      test('exact name match is case-insensitive', () {
        final runner = makeRunner('105', name: 'Alice Johnson');
        expect(PhoneticSearch.score('ALICE JOHNSON', runner), 0.9);
      });

      test('exact bib match is case-insensitive', () {
        final runner = makeRunner('ABC', name: 'Runner');
        expect(PhoneticSearch.score('abc', runner), 1.0);
      });
    });
  });
}
