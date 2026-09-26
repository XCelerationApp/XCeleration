import 'package:xceleration/core/app_error.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/database/base_models.dart';
import 'package:xceleration/shared/models/database/master_race.dart';

/// A runner the coach is adding while resolving a bib, as typed into the
/// create-runner sheet.
class NewRunner {
  const NewRunner({
    required this.name,
    required this.bibNumber,
    required this.teamName,
    required this.grade,
  });

  final String name;
  final String bibNumber;
  final String teamName;
  final int grade;
}

/// Saves [newRunner] and enters them in the race, so they can be given the
/// finish being resolved.
///
/// A bib belongs to one saved runner at most. A runner already saved with
/// this bib and name is reused rather than duplicated: they exist, they just
/// were not entered in this race. With a different name the bib is someone
/// else's, and nothing is saved: that used to give the finish to them.
Future<Result<RaceRunner>> saveNewRunner(
  MasterRace masterRace,
  NewRunner newRunner,
) async {
  try {
    final teams = await masterRace.teams;
    final team = teams.where((t) => t.name == newRunner.teamName).firstOrNull;
    if (team == null || team.teamId == null) {
      return Failure(AppError(
        userMessage: 'Team "${newRunner.teamName}" was not found. '
            'Choose one of the teams in this race.',
      ));
    }

    final runner = Runner(
      name: newRunner.name,
      bibNumber: newRunner.bibNumber,
      grade: newRunner.grade,
    );

    final existing = await masterRace.getRunnerByBib(newRunner.bibNumber);
    final Runner saved;
    if (existing?.runnerId != null) {
      String plain(String? s) => (s ?? '').trim().toLowerCase();
      if (plain(existing!.name) != plain(newRunner.name)) {
        return Failure(AppError(
          userMessage: 'Bib #${newRunner.bibNumber} is already '
              '${existing.name ?? 'another runner'}\'s. Add them by name, '
              'or give ${newRunner.name} a different bib.',
        ));
      }
      saved = existing;
    } else {
      final runnerId = await masterRace.createRunner(runner);
      await masterRace.addRunnerToTeam(team.teamId!, runnerId);
      saved = runner.copyWith(runnerId: runnerId);
    }

    await masterRace.addRaceParticipant(RaceParticipant(
      raceId: masterRace.raceId,
      runnerId: saved.runnerId!,
      teamId: team.teamId!,
    ));

    return Success(RaceRunner(
      raceId: masterRace.raceId,
      runner: saved,
      team: team,
    ));
  } catch (e) {
    Logger.e('Could not save a new runner: $e');
    return Failure(AppError(
      userMessage: 'Could not save the runner. Please try again.',
      originalException: e,
    ));
  }
}
