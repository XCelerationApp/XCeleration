import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/core/components/runner_form_validator.dart';

void main() {
  group('RunnerFormValidator', () {
    group('validateName', () {
      test('returns error for empty name', () {
        expect(RunnerFormValidator.validateName(''), 'Please enter a name');
      });

      test('returns null for a single-word name', () {
        expect(RunnerFormValidator.validateName('Alice'), isNull);
      });

      test('returns null for a full name with spaces', () {
        expect(RunnerFormValidator.validateName('John Doe'), isNull);
      });

      test('returns null for a name with special characters', () {
        expect(RunnerFormValidator.validateName("O'Brien"), isNull);
      });
    });

    group('validateGrade', () {
      test('returns error for empty grade', () {
        expect(RunnerFormValidator.validateGrade(''), 'Please enter a grade');
      });

      test('returns error for non-numeric input', () {
        expect(
          RunnerFormValidator.validateGrade('abc'),
          'Please enter a valid grade number',
        );
      });

      test('returns error for decimal input', () {
        expect(
          RunnerFormValidator.validateGrade('10.5'),
          'Please enter a valid grade number',
        );
      });

      test('returns error for grade below 9', () {
        expect(
          RunnerFormValidator.validateGrade('8'),
          'Grade must be between 9 and 12',
        );
      });

      test('returns error for grade 0', () {
        expect(
          RunnerFormValidator.validateGrade('0'),
          'Grade must be between 9 and 12',
        );
      });

      test('returns error for negative grade', () {
        expect(
          RunnerFormValidator.validateGrade('-1'),
          'Grade must be between 9 and 12',
        );
      });

      test('returns error for grade above 12', () {
        expect(
          RunnerFormValidator.validateGrade('13'),
          'Grade must be between 9 and 12',
        );
      });

      test('returns null for grade 9', () {
        expect(RunnerFormValidator.validateGrade('9'), isNull);
      });

      test('returns null for grade 10', () {
        expect(RunnerFormValidator.validateGrade('10'), isNull);
      });

      test('returns null for grade 11', () {
        expect(RunnerFormValidator.validateGrade('11'), isNull);
      });

      test('returns null for grade 12', () {
        expect(RunnerFormValidator.validateGrade('12'), isNull);
      });
    });

    group('validateBibFormat', () {
      test('returns error for empty bib', () {
        expect(
          RunnerFormValidator.validateBibFormat(''),
          'Please enter a bib number',
        );
      });

      test('returns error for non-numeric input', () {
        expect(
          RunnerFormValidator.validateBibFormat('abc'),
          'Please enter a valid bib number',
        );
      });

      test('returns error for decimal input', () {
        expect(
          RunnerFormValidator.validateBibFormat('1.5'),
          'Please enter a valid bib number',
        );
      });

      test('returns error for zero', () {
        expect(
          RunnerFormValidator.validateBibFormat('0'),
          'Please enter a bib number greater than 0',
        );
      });

      test('returns error for negative number', () {
        expect(
          RunnerFormValidator.validateBibFormat('-1'),
          'Please enter a bib number greater than 0',
        );
      });

      test('returns null for bib number 1', () {
        expect(RunnerFormValidator.validateBibFormat('1'), isNull);
      });

      test('returns null for a typical bib number', () {
        expect(RunnerFormValidator.validateBibFormat('42'), isNull);
      });

      test('returns null for a large bib number', () {
        expect(RunnerFormValidator.validateBibFormat('9999'), isNull);
      });
    });
  });
}
