import 'package:xceleration/shared/models/database/race_runner.dart';

/// One finish the coach is being asked about.
class ConflictOccurrence {
  const ConflictOccurrence({required this.place, this.time});

  /// Finish place, counting from 1.
  final int place;

  /// The Timer's time for that place, or null where the Timer flagged the
  /// stretch it falls in and which time belongs to whom is still in dispute.
  final String? time;
}

/// A finisher near a conflict whose own bib is not in question, shown so the
/// coach can tell who the disputed finish sits between.
class NearbyFinisher {
  const NearbyFinisher({
    required this.place,
    required this.name,
    required this.team,
    required this.bibNumber,
    this.time,
  });

  final int place;
  final String name;
  final String team;
  final String bibNumber;
  final String? time;
}

/// Something wrong with the finish order the Bib Recorder handed over.
sealed class BibConflict {
  const BibConflict({required this.bibNumber, required this.nearby});

  final String bibNumber;

  /// The nearest finisher either side, in finish order.
  final List<NearbyFinisher> nearby;

  /// Where the conflict sits in the finish order, for listing them in order.
  int get firstPlace;
}

/// A bib recorded at more than one finish. Only one of them is this runner;
/// the others belong to people whose bib was taken down wrong.
class DuplicateBibConflict extends BibConflict {
  const DuplicateBibConflict({
    required super.bibNumber,
    required this.runner,
    required this.occurrences,
    required super.nearby,
  });

  /// The runner the bib belongs to.
  final RaceRunner runner;

  /// Every place the bib was recorded at, in finish order. None of them is
  /// assumed correct: which one is this runner's is the question.
  final List<ConflictOccurrence> occurrences;

  @override
  int get firstPlace => occurrences.first.place;
}

/// A bib no runner has.
class UnknownBibConflict extends BibConflict {
  const UnknownBibConflict({
    required super.bibNumber,
    required this.occurrence,
    required super.nearby,
  });

  final ConflictOccurrence occurrence;

  @override
  int get firstPlace => occurrence.place;
}

/// Works out what is wrong with [entries], the finish order as the Bib
/// Recorder left it: a [RaceRunner] where the bib matched someone, or the bare
/// bib number where it did not.
///
/// [timesByPlace] gives the Timer's time for the places it has settled, and
/// [lookupBib] finds the runner holding a bib that was not matched.
Future<List<BibConflict>> detectBibConflicts({
  required List<dynamic> entries,
  required Map<int, String> timesByPlace,
  required Future<RaceRunner?> Function(String bibNumber) lookupBib,
}) async {
  // Every place each bib was recorded at, in finish order.
  final placesByBib = <String, List<int>>{};
  final runnersByBib = <String, RaceRunner>{};

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final bib = entry is RaceRunner ? entry.runner.bibNumber : entry as String?;
    if (bib == null) continue;
    placesByBib.putIfAbsent(bib, () => []).add(i + 1);
    if (entry is RaceRunner) runnersByBib[bib] = entry;
  }

  // A bib recorded more than once may have been matched at none of its
  // places, so ask who holds it before deciding it belongs to nobody.
  for (final bib in placesByBib.keys) {
    if (runnersByBib.containsKey(bib)) continue;
    if (placesByBib[bib]!.length < 2) continue;
    final runner = await lookupBib(bib);
    if (runner != null) runnersByBib[bib] = runner;
  }

  /// Which places are in dispute, so they can be kept out of the context.
  final disputed = <int>{};
  for (final entry in placesByBib.entries) {
    final isDuplicate = entry.value.length > 1 && runnersByBib.containsKey(entry.key);
    final isUnknown = !runnersByBib.containsKey(entry.key);
    if (isDuplicate || isUnknown) disputed.addAll(entry.value);
  }

  ConflictOccurrence occurrenceAt(int place) =>
      ConflictOccurrence(place: place, time: timesByPlace[place]);

  /// The nearest settled finisher either side of [place].
  List<NearbyFinisher> nearbyTo(int place) {
    NearbyFinisher? at(int candidate) {
      if (candidate < 1 || candidate > entries.length) return null;
      if (disputed.contains(candidate)) return null;
      final entry = entries[candidate - 1];
      if (entry is! RaceRunner) return null;
      return NearbyFinisher(
        place: candidate,
        name: entry.runner.name ?? '',
        team: entry.team.name ?? '',
        bibNumber: entry.runner.bibNumber ?? '',
        time: timesByPlace[candidate],
      );
    }

    NearbyFinisher? search(int from, int step) {
      for (var i = from; i >= 1 && i <= entries.length; i += step) {
        final found = at(i);
        if (found != null) return found;
      }
      return null;
    }

    return [
      ?search(place - 1, -1),
      ?search(place + 1, 1),
    ];
  }

  final conflicts = <BibConflict>[];
  for (final entry in placesByBib.entries) {
    final bib = entry.key;
    final places = entry.value;
    final runner = runnersByBib[bib];

    if (runner == null) {
      // Nobody has this bib. Each recording of it is its own question.
      for (final place in places) {
        conflicts.add(UnknownBibConflict(
          bibNumber: bib,
          occurrence: occurrenceAt(place),
          nearby: nearbyTo(place),
        ));
      }
    } else if (places.length > 1) {
      conflicts.add(DuplicateBibConflict(
        bibNumber: bib,
        runner: runner,
        occurrences: places.map(occurrenceAt).toList(),
        nearby: nearbyTo(places.first),
      ));
    }
  }

  conflicts.sort((a, b) => a.firstPlace.compareTo(b.firstPlace));
  return conflicts;
}
