/// Where a timing conflict most likely is, worked out the way a coach
/// would: a missed runner usually sits in the biggest gap between two
/// times, and a stray tap is usually right on top of another time.
library;

import 'package:xceleration/core/utils/time_formatter.dart';

/// A place in a group of times where the app thinks the problem is.
class TimingSpot {
  const TimingSpot({required this.row, required this.gap, this.clear = true});

  /// For a missing time, the row whose time comes just after the gap (its +
  /// puts the missing slot there), or the number of rows when the gap is
  /// after the last time. For an extra time, the row to remove.
  final int row;

  /// The gap that points to it: the biggest in the group for a missing
  /// time, the smallest for an extra one.
  final Duration gap;

  /// Whether it clearly stands out: a gap well bigger than any other for a
  /// missing time, two times well closer than any others for an extra one.
  /// When not, the spot is only the best of several like it.
  final bool clear;
}

Duration? _parse(String? t) => t == null || t == 'TBD' || t.isEmpty
    ? null
    : TimeFormatter.loadDurationFromString(t);

/// The time before each row's own, from the row above with a time (or
/// [start] for the first); null for a row without a time yet.
List<Duration?> gapsBefore(List<String> times, {String? start}) {
  var previous = _parse(start);
  final gaps = <Duration?>[];
  for (final t in times) {
    final time = _parse(t);
    if (time == null) {
      gaps.add(null);
      continue;
    }
    gaps.add(previous == null ? null : time - previous);
    previous = time;
  }
  return gaps;
}

/// Where a runner the Timer missed most likely finished: in the biggest gap
/// between known times, counting from [start] (the group before) to [end]
/// (the Timer's count check). Rows still showing "TBD" are skipped.
TimingSpot? likelyMissingSpot(List<String> times,
    {String? start, String? end}) {
  final known = <(int, Duration)>[
    for (var i = 0; i < times.length; i++)
      if (_parse(times[i]) case final d?) (i, d),
  ];
  final points = <(int, Duration)>[
    if (_parse(start) case final s?) (-1, s),
    ...known,
    if (_parse(end) case final e?) (times.length, e),
  ];
  final spots = <TimingSpot>[
    for (var k = 1; k < points.length; k++)
      if (!(points[k].$2 - points[k - 1].$2).isNegative)
        TimingSpot(row: points[k].$1, gap: points[k].$2 - points[k - 1].$2),
  ]..sort((a, b) => b.gap.compareTo(a.gap));
  if (spots.isEmpty) return null;
  final best = spots.first;
  // Clear when half again as big as the next biggest gap.
  final clear = spots.length == 1 ||
      best.gap.inMilliseconds >= spots[1].gap.inMilliseconds * 1.5;
  return TimingSpot(row: best.row, gap: best.gap, clear: clear);
}

/// The time most likely a stray tap: the second of the two times closest
/// together (a double tap lands right after the real one).
TimingSpot? likelyExtraTime(List<String> times, {String? start}) {
  final gaps = gapsBefore(times, start: start);
  final spots = <TimingSpot>[
    for (var i = 0; i < gaps.length; i++)
      if (gaps[i] case final gap? when !gap.isNegative)
        TimingSpot(row: i, gap: gap),
  ]..sort((a, b) => a.gap.compareTo(b.gap));
  if (spots.isEmpty) return null;
  final best = spots.first;
  // Clear when under half a second (a double tap), or half the next
  // closest gap.
  final clear = best.gap < const Duration(milliseconds: 500) ||
      spots.length == 1 ||
      best.gap.inMilliseconds * 2 <= spots[1].gap.inMilliseconds;
  return TimingSpot(row: best.row, gap: best.gap, clear: clear);
}

/// The time halfway between [after] and [before], written the way the
/// Timer writes times, for a best guess at a missing time.
String? midpointTime(String? after, String? before) {
  final a = _parse(after), b = _parse(before);
  if (a == null || b == null || b <= a) return null;
  return TimeFormatter.formatDuration(a + (b - a) ~/ 2);
}

/// A gap as a coach would say it: "0.2 s" or "12.3 s".
String describeGap(Duration gap) =>
    '${(gap.inMilliseconds / 1000).toStringAsFixed(1)} s';
