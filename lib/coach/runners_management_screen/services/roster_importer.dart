import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/shared/models/database/team_participant.dart';

/// A runner already saved under a bib, whose spreadsheet row gives a
/// different name or grade. The coach decides which to keep; the runner is
/// already on the team and in the race either way.
class RunnerDetailsConflict {
  const RunnerDetailsConflict({
    required this.existing,
    required this.name,
    required this.grade,
  });

  final Runner existing;

  /// The name and grade the spreadsheet gives.
  final String name;
  final int grade;
}

/// What an import did, for the coach to be told.
class RosterImportResult {
  const RosterImportResult({
    required this.added,
    required this.alreadyKnown,
    required this.teamsCreated,
    required this.teamsAdded,
    required this.conflicts,
    required this.unplaced,
  });

  /// Runners created by the import.
  final int added;

  /// Runners the app already had under the same bib, now on the team given.
  final int alreadyKnown;

  /// Teams created because no team had the spreadsheet's name.
  final List<String> teamsCreated;

  /// Teams brought into this race (created or already known).
  final List<String> teamsAdded;

  /// Saved runners whose name or grade differs from the spreadsheet.
  final List<RunnerDetailsConflict> conflicts;

  /// Rows left out because they named no team and none was given.
  final int unplaced;

  int get total => added + alreadyKnown;
}

/// Puts spreadsheet rows into a race: each runner onto a team, and each
/// team into the race.
///
/// A row's own team (from a Team or School column) wins; rows without one
/// go to the team the import was started from. Teams are matched by name,
/// then by abbreviation, ignoring case, and created when neither matches.
/// Runners are matched by bib, which is unique among a coach's runners: a
/// known bib is put on the team and in the race without changing its
/// details, and any difference is returned for the coach to settle.
class RosterImporter {
  RosterImporter({
    required this.raceId,
    required IRunnerRepository runners,
    required ITeamRepository teams,
    required IRaceRepository races,
  })  : _runners = runners,
        _teams = teams,
        _races = races;

  final int raceId;
  final IRunnerRepository _runners;
  final ITeamRepository _teams;
  final IRaceRepository _races;

  /// Imports [rows] (as [processSpreadsheetData] gives them). Rows without a
  /// team go to [intoTeam]; with neither they are counted as unplaced.
  Future<RosterImportResult> importRows(
    List<Map<String, dynamic>> rows, {
    Team? intoTeam,
  }) async {
    final created = <String>[];
    final inRace = <String>[];
    final conflicts = <RunnerDetailsConflict>[];
    final teamsByKey = <String, Team>{};
    var added = 0;
    var known = 0;
    var unplaced = 0;

    Future<Team> teamFor(String named) async {
      final key = named.trim().toLowerCase();
      final cached = teamsByKey[key];
      if (cached != null) return cached;
      var team = await _findTeam(named.trim());
      if (team == null) {
        final all = await _teams.getAllTeams();
        final id = await _teams.createTeam(Team(
          name: named.trim(),
          abbreviation: abbreviate(named),
          // Three steps round the colour wheel at a time, so teams made one
          // after another do not come out nearly the same colour.
          color: Team.generateColor(all.length * 3),
        ));
        team = await _teams.getTeam(id) ??
            Team(teamId: id, name: named.trim(), abbreviation: abbreviate(named));
        created.add(named.trim());
      }
      return teamsByKey[key] = team;
    }

    Future<void> ensureInRace(Team team) async {
      final participant =
          TeamParticipant(raceId: raceId, teamId: team.teamId);
      if (await _races.getRaceTeamParticipant(participant) == null) {
        await _races.addTeamParticipantToRace(TeamParticipant(
          raceId: raceId,
          teamId: team.teamId,
          colorOverride: team.color?.toARGB32(),
        ));
      }
      final name = team.name ?? '';
      if (!inRace.contains(name)) inRace.add(name);
    }

    for (final row in rows) {
      final name = (row['name'] as String?)?.trim() ?? '';
      final grade = (row['grade'] as int?) ?? 0;
      final bib = (row['bib'] as String?)?.trim() ?? '';
      if (name.isEmpty || bib.isEmpty || grade < 9 || grade > 12) continue;

      final teamName = (row['team'] as String?)?.trim() ?? '';
      final Team? team =
          teamName.isNotEmpty ? await teamFor(teamName) : intoTeam;
      if (team?.teamId == null) {
        unplaced++;
        continue;
      }
      final teamId = team!.teamId!;
      await ensureInRace(team);

      final existing = await _runners.getRunnerByBib(bib);
      if (existing == null) {
        final runnerId = await _runners
            .createRunner(Runner(name: name, bibNumber: bib, grade: grade));
        await _runners.addRunnerToTeam(teamId, runnerId);
        await _races.addRaceParticipant(RaceParticipant(
            raceId: raceId, runnerId: runnerId, teamId: teamId));
        added++;
        continue;
      }

      known++;
      await _placeInRace(existing.runnerId!, bib, teamId);
      if (existing.name != name || (existing.grade ?? 0) != grade) {
        conflicts.add(
            RunnerDetailsConflict(existing: existing, name: name, grade: grade));
      }
    }

    return RosterImportResult(
      added: added,
      alreadyKnown: known,
      teamsCreated: created,
      teamsAdded: inRace,
      conflicts: conflicts,
      unplaced: unplaced,
    );
  }

  /// Takes the spreadsheet's name and grade for a runner already saved.
  /// Their past results stay with them.
  Future<void> useSpreadsheetDetails(RunnerDetailsConflict conflict) async {
    final existing = conflict.existing;
    await _runners.updateRunner(Runner(
      runnerId: existing.runnerId,
      uuid: existing.uuid,
      name: conflict.name,
      bibNumber: existing.bibNumber,
      grade: conflict.grade,
    ));
  }

  /// Puts a saved runner on [teamId], in this race.
  Future<void> _placeInRace(int runnerId, String bib, int teamId) async {
    await _runners.addRunnerToTeam(teamId, runnerId);
    final participant = await _races.getRaceParticipantByBib(raceId, bib);
    if (participant == null) {
      await _races.addRaceParticipant(RaceParticipant(
          raceId: raceId, runnerId: runnerId, teamId: teamId));
    } else if (participant.teamId != teamId) {
      await _races.updateRaceParticipantTeam(
          raceId: raceId, runnerId: runnerId, newTeamId: teamId);
    }
  }

  /// A team named [named], or abbreviated so, ignoring case.
  Future<Team?> _findTeam(String named) async {
    final exact = await _teams.getTeamByName(named);
    if (exact != null) return exact;
    final key = named.toLowerCase();
    for (final team in await _teams.getAllTeams()) {
      if ((team.name ?? '').toLowerCase() == key ||
          (team.abbreviation ?? '').toLowerCase() == key) {
        return team;
      }
    }
    return null;
  }

  /// A short form of a team name: the first letter of up to three words,
  /// or the first three letters of a one-word name. A boys' or girls' team
  /// ends in B or G, so "Archie Williams - Boys" and "- Girls" differ (AWB,
  /// AWG). Dashes and the like are not words.
  static String abbreviate(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => RegExp(r'^[A-Za-z0-9]').hasMatch(w))
        .toList();
    if (words.isEmpty) return '';
    final last = words.last.toLowerCase();
    final side = switch (last) {
      'boys' || 'boy' => 'B',
      'girls' || 'girl' => 'G',
      _ => null,
    };
    if (side != null && words.length > 1) {
      final base = words.sublist(0, words.length - 1);
      final start = base.length == 1
          ? base.first.substring(0, base.first.length < 2 ? 1 : 2)
          : base.take(2).map((w) => w[0]).join();
      return (start + side).toUpperCase();
    }
    if (words.length == 1) {
      final w = words.first;
      return (w.length <= 3 ? w : w.substring(0, 3)).toUpperCase();
    }
    return words.take(3).map((w) => w[0].toUpperCase()).join();
  }

  /// [rows] with each runner's team split into a boys' and a girls' team,
  /// such as "Archie Williams - Boys", by the spreadsheet's gender column.
  /// A runner with no gender or no team stays on the team as it is.
  static List<Map<String, dynamic>> splitTeamsByGender(
      List<Map<String, dynamic>> rows) {
    return [
      for (final row in rows)
        () {
          final team = (row['team'] as String?)?.trim() ?? '';
          final gender = (row['gender'] as String?)?.toUpperCase() ?? '';
          final side = switch (gender) {
            'M' => 'Boys',
            'F' => 'Girls',
            _ => null,
          };
          if (team.isEmpty || side == null) return row;
          return {...row, 'team': '$team - $side'};
        }(),
    ];
  }
}
