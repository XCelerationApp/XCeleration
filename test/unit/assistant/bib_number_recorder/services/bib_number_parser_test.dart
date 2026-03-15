import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/bib_number_parser.dart';

void main() {
  late BibNumberParser parser;

  setUp(() {
    parser = const BibNumberParser();
  });

  group('BibNumberParser', () {
    group('parse — empty / invalid input', () {
      test('returns null for empty string', () {
        expect(parser.parse(''), isNull);
      });

      test('returns null for whitespace only', () {
        expect(parser.parse('   '), isNull);
      });

      test('returns null for unrecognised words', () {
        expect(parser.parse('hello world'), isNull);
      });

      test('returns null for zero (out of bib range)', () {
        expect(parser.parse('zero'), isNull);
      });

      test('returns null for values above 9999', () {
        // "ten thousand" would parse to 10000
        expect(parser.parse('ten thousand'), isNull);
      });
    });

    group('parse — single digits', () {
      test('one → 1', () => expect(parser.parse('one'), equals(1)));
      test('nine → 9', () => expect(parser.parse('nine'), equals(9)));
    });

    group('parse — chunked (digit-by-digit)', () {
      test('one two → 12', () => expect(parser.parse('one two'), equals(12)));
      test('one two three → 123',
          () => expect(parser.parse('one two three'), equals(123)));
      test('one two three four → 1234',
          () => expect(parser.parse('one two three four'), equals(1234)));
      test('nine nine nine nine → 9999',
          () => expect(parser.parse('nine nine nine nine'), equals(9999)));
    });

    group('parse — chunked (tens groups)', () {
      test('twenty three → 23',
          () => expect(parser.parse('twenty three'), equals(23)));
      test('forty five → 45',
          () => expect(parser.parse('forty five'), equals(45)));
      test('twelve thirty four → 1234',
          () => expect(parser.parse('twelve thirty four'), equals(1234)));
      test('ninety nine → 99',
          () => expect(parser.parse('ninety nine'), equals(99)));
      test('standalone tens: thirty → 30',
          () => expect(parser.parse('thirty'), equals(30)));
    });

    group('parse — natural English (hundred / thousand)', () {
      test('one hundred → 100',
          () => expect(parser.parse('one hundred'), equals(100)));
      test('one hundred and three → 103',
          () => expect(parser.parse('one hundred and three'), equals(103)));
      test('two hundred and fifty six → 256',
          () => expect(parser.parse('two hundred and fifty six'), equals(256)));
      test('one thousand → 1000',
          () => expect(parser.parse('one thousand'), equals(1000)));
      test('one thousand two hundred and thirty four → 1234',
          () => expect(
              parser.parse('one thousand two hundred and thirty four'),
              equals(1234)));
      test('nine thousand nine hundred and ninety nine → 9999',
          () => expect(
              parser.parse('nine thousand nine hundred and ninety nine'),
              equals(9999)));
    });

    group('parse — "and" is ignored as filler', () {
      test('"and" alone returns null', () {
        expect(parser.parse('and'), isNull);
      });
      test('"and" between words is stripped', () {
        expect(parser.parse('twenty and three'), equals(23));
      });
    });

    group('parse — boundary values', () {
      test('1 is valid', () => expect(parser.parse('one'), equals(1)));
      test('9999 is valid',
          () => expect(parser.parse('nine thousand nine hundred and ninety nine'),
              equals(9999)));
    });
  });
}
