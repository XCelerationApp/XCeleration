import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

Runner _validRunner({
  int runnerId = 1,
  String name = 'Alice',
  String bibNumber = '42',
  int grade = 10,
}) =>
    Runner(
      runnerId: runnerId,
      name: name,
      bibNumber: bibNumber,
      grade: grade,
    );

Team _validTeam({
  int teamId = 1,
  String name = 'Eagles',
  String abbreviation = 'EAG',
}) =>
    Team(
      teamId: teamId,
      name: name,
      abbreviation: abbreviation,
      color: const Color(0xFF2196F3),
    );

void main() {
  group('RaceRunner', () {
    group('isValid', () {
      test('returns true when raceId > 0 and runner and team are valid', () {
        final raceRunner = RaceRunner(
          raceId: 1,
          runner: _validRunner(),
          team: _validTeam(),
        );
        expect(raceRunner.isValid, isTrue);
      });

      test('returns false when raceId is 0', () {
        final raceRunner = RaceRunner(
          raceId: 0,
          runner: _validRunner(),
          team: _validTeam(),
        );
        expect(raceRunner.isValid, isFalse);
      });

      test('returns false when raceId is negative', () {
        final raceRunner = RaceRunner(
          raceId: -1,
          runner: _validRunner(),
          team: _validTeam(),
        );
        expect(raceRunner.isValid, isFalse);
      });

      test('returns false when runner is invalid (missing name)', () {
        final raceRunner = RaceRunner(
          raceId: 1,
          runner: _validRunner(name: ''),
          team: _validTeam(),
        );
        expect(raceRunner.isValid, isFalse);
      });

      test('returns false when runner grade is out of range', () {
        final raceRunner = RaceRunner(
          raceId: 1,
          runner: _validRunner(grade: 8),
          team: _validTeam(),
        );
        expect(raceRunner.isValid, isFalse);
      });

      test('returns false when team is invalid (missing name)', () {
        final raceRunner = RaceRunner(
          raceId: 1,
          runner: _validRunner(),
          team: _validTeam(name: ''),
        );
        expect(raceRunner.isValid, isFalse);
      });
    });

    group('copy', () {
      test('returns a new instance with identical field values', () {
        final original = RaceRunner(
          raceId: 5,
          runner: _validRunner(runnerId: 10, name: 'Bob', bibNumber: '99', grade: 11),
          team: _validTeam(teamId: 3, name: 'Hawks', abbreviation: 'HWK'),
        );

        final copy = original.copy();

        expect(copy.raceId, original.raceId);
        expect(copy.runner.runnerId, original.runner.runnerId);
        expect(copy.runner.name, original.runner.name);
        expect(copy.runner.bibNumber, original.runner.bibNumber);
        expect(copy.runner.grade, original.runner.grade);
        expect(copy.team.teamId, original.team.teamId);
        expect(copy.team.name, original.team.name);
        expect(copy.team.abbreviation, original.team.abbreviation);
      });

      test('returns a different object (deep copy)', () {
        final original = RaceRunner(
          raceId: 1,
          runner: _validRunner(),
          team: _validTeam(),
        );

        final copy = original.copy();

        expect(identical(copy, original), isFalse);
        expect(identical(copy.runner, original.runner), isFalse);
        expect(identical(copy.team, original.team), isFalse);
      });
    });

    group('RaceRunner.from', () {
      test('creates a deep copy identical to copy()', () {
        final original = RaceRunner(
          raceId: 7,
          runner: _validRunner(name: 'Carol'),
          team: _validTeam(name: 'Tigers'),
        );

        final fromCopy = RaceRunner.from(original);

        expect(fromCopy.raceId, original.raceId);
        expect(fromCopy.runner.name, original.runner.name);
        expect(fromCopy.team.name, original.team.name);
        expect(identical(fromCopy, original), isFalse);
      });
    });
  });
}
