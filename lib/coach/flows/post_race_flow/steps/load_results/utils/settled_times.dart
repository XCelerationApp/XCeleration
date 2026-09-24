import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';

/// The finish time for each place the Timer is not still unsure about, keyed
/// by place (1 for first).
///
/// Bib conflicts are resolved before timing conflicts, so when the coach is
/// asked which finish belongs to a runner, part of the Timer's data may still
/// be in dispute. A place inside a flagged stretch has no time yet — which
/// time belongs to which runner there is the thing being disputed — and is
/// left out rather than guessed at. Every other place is included, including
/// the ones after a flagged stretch: a flagged chunk still accounts for a
/// known number of finishers, so the places that follow it line up.
Map<int, String> settledTimesByPlace(List<TimingChunk> chunks) {
  final times = <int, String>{};
  var place = 1;

  for (final chunk in chunks) {
    final finishers = chunk.recordCount;
    // A chunk is settled when it holds exactly one real time per finisher.
    final settled = finishers == chunk.timingData.length &&
        chunk.timingData.every((datum) => datum.time != 'TBD');

    if (settled) {
      for (final datum in chunk.timingData) {
        times[place++] = datum.time;
      }
    } else {
      place += finishers < 0 ? 0 : finishers;
    }
  }

  return times;
}
