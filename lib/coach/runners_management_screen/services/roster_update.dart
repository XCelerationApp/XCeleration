import 'package:xceleration/core/repositories/i_race_repository.dart';
import 'package:xceleration/core/repositories/i_runner_repository.dart';
import 'package:xceleration/core/repositories/i_team_repository.dart';
import 'package:xceleration/shared/models/database/race_participant.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

import 'roster_importer.dart';

/// A runner whose details on the spreadsheet differ from the app's.
class RunnerChange {
  const RunnerChange({required this.before, required this.after});

  final Runner before;
  final Runner after;
}

/// What updating a team from a newer spreadsheet would do, for the coach to
/// check before anything changes.
class RosterUpdatePlan {
  const RosterUpdatePlan({
    this.added = const [],
    this.changed = const [],
    this.removed = const [],
  });

  /// Rows for runners the team does not have yet.
  final List<Map<String, dynamic>> added;

  /// Runners on the team whose name, grade or bib changed.
  final List<RunnerChange> changed;

  /// Runners on the team the spreadsheet no longer lists. They come off the
  /// team (and this race), but keep their past results.
  final List<Runner> removed;

  bool get isEmpty => added.isEmpty && changed.isEmpty && removed.isEmpty;
}

/// The rows of a spreadsheet that belong to [team]. A sheet without a Team
/// column is all one team's. Otherwise rows naming the team (or its short
/// name) count, and for a team split into boys and girls, such as
/// "Archie Williams - Boys", the school's rows of that gender.
List<Map<String, dynamic>> rowsForTeam(
    List<Map<String, dynamic>> rows, Team team) {
  final hasTeamColumn =
      rows.any((r) => ((r['team'] as String?)?.trim() ?? '').isNotEmpty);
  if (!hasTeamColumn) return rows;

  String key(String? s) => (s ?? '').trim().toLowerCase();
  final name = key(team.name);
  final abbreviation = key(team.abbreviation);
  return [
    for (final row in rows)
      if (() {
        final rowTeam = key(row['team'] as String?);
        if (rowTeam.isEmpty) return false;
        if (rowTeam == name || rowTeam == abbreviation) return true;
        final gender = key(row['gender'] as String?);
        return (gender == 'm' && '$rowTeam - boys' == name) ||
            (gender == 'f' && '$rowTeam - girls' == name);
      }())
        row,
  ];
}

/// Compares [team]'s runners with the spreadsheet's [rows] for it. A runner
/// is matched by bib first, then by name, so a runner given a new bib is a
/// change, not a removal and an addition.
RosterUpdatePlan planRosterUpdate({
  required List<Runner> current,
  required List<Map<String, dynamic>> rows,
}) {
  String nameKey(String? s) =>
      (s ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  final unmatched = [...current];
  final pairs = <(Runner, Map<String, dynamic>)>[];
  final newRows = <Map<String, dynamic>>[];
  final waiting = <Map<String, dynamic>>[];

  // By bib first.
  for (final row in rows) {
    final bib = '${row['bib'] ?? ''}'.trim();
    final i = unmatched.indexWhere((r) => r.bibNumber == bib && bib.isNotEmpty);
    if (i >= 0) {
      pairs.add((unmatched.removeAt(i), row));
    } else {
      waiting.add(row);
    }
  }
  // Then by name, for a runner whose bib changed.
  for (final row in waiting) {
    final name = nameKey(row['name'] as String?);
    final i = unmatched.indexWhere((r) => nameKey(r.name) == name);
    if (i >= 0) {
      pairs.add((unmatched.removeAt(i), row));
    } else {
      newRows.add(row);
    }
  }

  final changed = <RunnerChange>[];
  for (final (runner, row) in pairs) {
    final name = '${row['name'] ?? ''}'.trim();
    final bib = '${row['bib'] ?? ''}'.trim();
    final grade = row['grade'] is int
        ? row['grade'] as int
        : int.tryParse('${row['grade']}');
    final after = runner.copyWith(
      name: name.isEmpty ? null : name,
      bibNumber: bib.isEmpty ? null : bib,
      grade: grade,
    );
    if (after.name != runner.name ||
        after.bibNumber != runner.bibNumber ||
        after.grade != runner.grade) {
      changed.add(RunnerChange(before: runner, after: after));
    }
  }

  return RosterUpdatePlan(
    added: newRows,
    changed: changed,
    removed: unmatched,
  );
}

/// What [RosterUpdater.apply] did.
class RosterUpdateResult {
  const RosterUpdateResult({
    required this.imported,
    required this.changed,
    required this.removed,
    required this.bibTaken,
  });

  /// The new runners, added through [RosterImporter] (so a bib the coach
  /// already has elsewhere comes back as a conflict to settle).
  final RosterImportResult imported;
  final int changed;
  final int removed;

  /// Changes left out because the new bib belongs to another runner.
  final List<RunnerChange> bibTaken;
}

/// Carries out a [RosterUpdatePlan] for one team in one race.
class RosterUpdater {
  RosterUpdater({
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

  Future<RosterUpdateResult> apply(RosterUpdatePlan plan, Team team) async {
    final teamId = team.teamId!;

    var changed = 0;
    final bibTaken = <RunnerChange>[];
    for (final change in plan.changed) {
      final newBib = change.after.bibNumber;
      if (newBib != null && newBib != change.before.bibNumber) {
        final holder = await _runners.getRunnerByBib(newBib);
        if (holder != null && holder.runnerId != change.before.runnerId) {
          bibTaken.add(change);
          continue;
        }
      }
      await _runners.updateRunner(change.after);
      changed++;
    }

    // Off this team and this race only: the runner and their past results
    // stay.
    for (final runner in plan.removed) {
      await _runners.removeRunnerFromTeam(teamId, runner.runnerId!);
      final participant =
          RaceParticipant(raceId: raceId, runnerId: runner.runnerId);
      if (await _races.getRaceParticipant(participant) != null) {
        await _races.removeRaceParticipant(participant);
      }
    }

    // The rows were matched to this team already, so any Team column is
    // dropped to keep them from landing on another.
    final imported = await RosterImporter(
      raceId: raceId,
      runners: _runners,
      teams: _teams,
      races: _races,
    ).importRows(
      [for (final row in plan.added) {...row}..remove('team')],
      intoTeam: team,
    );

    return RosterUpdateResult(
      imported: imported,
      changed: changed,
      removed: plan.removed.length,
      bibTaken: bibTaken,
    );
  }
}
