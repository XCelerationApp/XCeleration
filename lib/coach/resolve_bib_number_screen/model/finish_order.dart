/// The finish order as the Bib Recorder left it is a list read by position:
/// place is index plus one, and the times are handed out from it. These write
/// a resolution back into that list without disturbing anything else in it.
library;

import 'package:xceleration/shared/models/database/race_runner.dart';

/// [entries] with the runner in [settled] written into each of their places.
///
/// Keyed by place, counting from 1. A place outside the race is ignored rather
/// than shifting everything after it.
List<dynamic> applyResolvedFinishes(
  List<dynamic> entries,
  Map<int, RaceRunner> settled,
) {
  final updated = List<dynamic>.from(entries);
  for (final entry in settled.entries) {
    final index = entry.key - 1;
    if (index < 0 || index >= updated.length) continue;
    updated[index] = entry.value;
  }
  return updated;
}

/// [entries] without the finish at [place], everyone after it moving up one.
///
/// Only for a finish that should never have been recorded. A repeated bib is
/// not one of those: somebody crossed the line there.
List<dynamic> removeFinish(List<dynamic> entries, int place) {
  final index = place - 1;
  if (index < 0 || index >= entries.length) return List<dynamic>.from(entries);
  return List<dynamic>.from(entries)..removeAt(index);
}
