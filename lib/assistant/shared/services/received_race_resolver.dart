import 'package:xceleration/assistant/shared/models/race_record.dart';
import 'package:xceleration/assistant/shared/services/i_assistant_storage_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

/// What the volunteer chose for a race the coach sent that matches one
/// already on the phone.
enum ReceivedRaceChoice {
  /// Open the race already here, keeping what was recorded for it, with the
  /// coach's name, date and roster.
  update,

  /// Keep the race already here as it is and open the one sent beside it.
  keepSeparate,
}

/// A race the coach sent under the number of a race already on the phone.
class RaceAlreadyHere {
  const RaceAlreadyHere({
    required this.existing,
    required this.sent,
    required this.recorded,
    this.rosterChanges,
  });

  final RaceRecord existing;
  final RaceRecord sent;

  /// Bibs or times recorded for [existing].
  final int recorded;

  /// How the coach's roster differs from the one here, for the Bib Recorder.
  final RosterChanges? rosterChanges;

  /// True when the name or date differs: the coach renamed the race, or it
  /// is another coach's race that happens to share the number.
  bool get renamed =>
      existing.name != sent.name ||
      existing.date.millisecondsSinceEpoch != sent.date.millisecondsSinceEpoch;
}

/// How a roster the coach sent differs from the one on the phone.
class RosterChanges {
  const RosterChanges({this.added = 0, this.removed = 0, this.changed = 0});

  factory RosterChanges.between(List<BibDatum> before, List<BibDatum> after) {
    final old = {for (final r in before) r.bib: r};
    final now = {for (final r in after) r.bib: r};
    var changed = 0;
    for (final r in after) {
      final was = old[r.bib];
      if (was != null &&
          (was.name != r.name ||
              was.teamAbbreviation != r.teamAbbreviation ||
              was.grade != r.grade)) {
        changed++;
      }
    }
    return RosterChanges(
      added: now.keys.where((b) => !old.containsKey(b)).length,
      removed: old.keys.where((b) => !now.containsKey(b)).length,
      changed: changed,
    );
  }

  final int added;
  final int removed;
  final int changed;

  bool get isEmpty => added == 0 && removed == 0 && changed == 0;

  /// "3 runners added, 1 removed", or null when nothing changed.
  String? describe() {
    if (isEmpty) return null;
    final parts = [
      if (added > 0) '$added added',
      if (removed > 0) '$removed removed',
      if (changed > 0) '$changed changed',
    ];
    final total = added + removed + changed;
    return '${total == 1 ? '1 runner' : '$total runners'}: ${parts.join(', ')}';
  }
}

typedef AskAboutRace = Future<ReceivedRaceChoice> Function(RaceAlreadyHere);

/// Works out where a race the coach sent goes, asking the volunteer when
/// only they can tell.
///
/// A race new to the phone is stored. The same race again (number, name and
/// date) opens the one here; if something was recorded for it, [ask] chooses
/// between updating it and keeping a separate copy. A race under the number
/// of one with another name or date may be the same race renamed by the
/// coach, or another coach's race: [ask] says which. Without [ask] the race
/// here is updated, which never loses anything recorded.
Future<Result<ReceivedRace>> resolveReceivedRace({
  required IAssistantStorageService storage,
  required RaceRecord sent,
  required Future<int> Function(RaceRecord existing) countRecorded,
  Future<RosterChanges?> Function(RaceRecord existing)? rosterChanges,
  AskAboutRace? ask,
}) async {
  final RaceRecord? existing;
  switch (await storage.getRace(sent.raceId, sent.type)) {
    case Failure(:final error):
      return Failure(error);
    case Success(:final value):
      existing = value;
  }
  if (existing == null) return storage.receiveRace(sent);

  final here = RaceAlreadyHere(
    existing: existing,
    sent: sent,
    recorded: await countRecorded(existing),
    rosterChanges: await rosterChanges?.call(existing),
  );
  if (!here.renamed && here.recorded == 0) {
    return Success(ReceivedRace(race: existing, isNew: false));
  }

  final choice = await ask?.call(here) ?? ReceivedRaceChoice.update;
  switch (choice) {
    case ReceivedRaceChoice.update:
      if (!here.renamed) {
        return Success(ReceivedRace(race: existing, isNew: false));
      }
      final renamed = RaceRecord(
        raceId: existing.raceId,
        date: sent.date,
        name: sent.name,
        type: existing.type,
        startedAt: existing.startedAt,
        stopped: existing.stopped,
        duration: existing.duration,
      );
      return switch (await storage.updateRace(renamed)) {
        Failure(:final error) => Failure(error),
        Success() => Success(ReceivedRace(race: renamed, isNew: false)),
      };
    case ReceivedRaceChoice.keepSeparate:
      final copy = RaceRecord(
        raceId: sent.raceId,
        date: sent.date,
        // Two races of one name in Other Races could not be told apart.
        name: here.renamed ? sent.name : '${sent.name} (copy)',
        type: sent.type,
      );
      return switch (await storage.saveRaceAsNew(copy)) {
        Failure(:final error) => Failure(error),
        Success(:final value) => Success(ReceivedRace(race: value, isNew: true)),
      };
  }
}
