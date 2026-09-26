import 'package:xceleration/shared/models/database/race_runner.dart';

/// One finish the coach is being asked about.
class ConflictOccurrence {
  const ConflictOccurrence({
    required this.place,
    this.time,
    this.after,
    this.before,
    this.approximate,
    this.nearby = const [],
    this.allFinishers = const [],
  });

  /// Finish place, counting from 1.
  final int place;

  /// The Timer's time for that place, or null where the Timer flagged the
  /// stretch it falls in and which time belongs to whom is still in dispute.
  final String? time;

  /// While [time] is unknown, the nearest known times either side: the
  /// finish came after [after] and before [before]. Either may be null.
  final String? after;
  final String? before;

  /// While [time] is unknown, the Timer's time near this place, to the
  /// second: only a guide, as a missed or extra tap shifts times a place.
  final String? approximate;

  /// [time], or where it must fall while it is still unknown, such as
  /// "Between 15:28.46 and 15:33.00". Null when nothing is known.
  String? get timeLabel {
    if (time != null) return time;
    if (approximate != null) return 'About $approximate';
    if (after != null && before != null) return 'Between $after and $before';
    if (after != null) return 'After $after';
    if (before != null) return 'Before $before';
    return null;
  }

  /// Settled finishers around this place, up to [nearbyWindow] either side,
  /// in finish order. The card shows the nearest one each side and "See more"
  /// shows the rest. Each finish carries its own: choosing between two of them
  /// means knowing who each one sits between.
  final List<NearbyFinisher> nearby;

  /// Every settled finisher in the race, in finish order, for "Show all
  /// finishers" when the few either side are not enough to go on. One list
  /// shared by every occurrence.
  final List<NearbyFinisher> allFinishers;
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

/// How many settled finishers either side of a disputed place to carry.
const nearbyWindow = 4;

/// Something wrong with the finish order the Bib Recorder handed over.
sealed class BibConflict {
  const BibConflict({required this.bibNumber});

  final String bibNumber;

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
  Map<int, String> approximateTimes = const {},
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

  /// The settled finishers around [place], up to [nearbyWindow] either side,
  /// in finish order. A finisher whose own bib is in question is skipped: they
  /// are no help in placing anyone else.
  List<NearbyFinisher> nearbyTo(int place) {
    NearbyFinisher? at(int candidate) {
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

    final ahead = <NearbyFinisher>[];
    for (var i = place - 1; i >= 1 && ahead.length < nearbyWindow; i--) {
      final found = at(i);
      if (found != null) ahead.add(found);
    }
    final behind = <NearbyFinisher>[];
    for (var i = place + 1;
        i <= entries.length && behind.length < nearbyWindow;
        i++) {
      final found = at(i);
      if (found != null) behind.add(found);
    }
    return [...ahead.reversed, ...behind];
  }

  // Every settled finisher, for the whole finish list.
  final allFinishers = <NearbyFinisher>[
    for (var place = 1; place <= entries.length; place++)
      if (!disputed.contains(place) && entries[place - 1] is RaceRunner)
        NearbyFinisher(
          place: place,
          name: (entries[place - 1] as RaceRunner).runner.name ?? '',
          team: (entries[place - 1] as RaceRunner).team.name ?? '',
          bibNumber: (entries[place - 1] as RaceRunner).runner.bibNumber ?? '',
          time: timesByPlace[place],
        ),
  ];

  // The nearest known time before and after a place whose own time is not.
  final knownPlaces = timesByPlace.keys.toList()..sort();
  String? knownBefore(int place) {
    final earlier = knownPlaces.where((p) => p < place);
    return earlier.isEmpty ? null : timesByPlace[earlier.last];
  }

  String? knownAfter(int place) {
    final later = knownPlaces.where((p) => p > place);
    return later.isEmpty ? null : timesByPlace[later.first];
  }

  ConflictOccurrence occurrenceAt(int place) => ConflictOccurrence(
        place: place,
        time: timesByPlace[place],
        after: timesByPlace[place] == null ? knownBefore(place) : null,
        before: timesByPlace[place] == null ? knownAfter(place) : null,
        approximate:
            timesByPlace[place] == null ? approximateTimes[place] : null,
        nearby: nearbyTo(place),
        allFinishers: allFinishers,
      );

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
        ));
      }
    } else if (places.length > 1) {
      conflicts.add(DuplicateBibConflict(
        bibNumber: bib,
        runner: runner,
        occurrences: places.map(occurrenceAt).toList(),
      ));
    }
  }

  conflicts.sort((a, b) => a.firstPlace.compareTo(b.firstPlace));
  return conflicts;
}
