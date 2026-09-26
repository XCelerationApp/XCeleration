/// The gaps between times in a timing conflict, and where a stray tap most
/// likely is: usually right on top of another time. A missed runner could
/// be anywhere, so nothing here guesses where one was.
library;

import 'package:xceleration/core/utils/time_formatter.dart';

/// A time in a group that the app thinks is a stray tap.
class TimingSpot {
  const TimingSpot({required this.row, required this.gap, this.clear = true});

  /// The row whose time looks like the stray tap.
  final int row;

  /// The gap before it: the smallest in the group.
  final Duration gap;

  /// Whether it clearly stands out: two times well closer than any others.
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

/// A gap as a coach would say it: "0.2 s" or "12.3 s".
String describeGap(Duration gap) =>
    '${(gap.inMilliseconds / 1000).toStringAsFixed(1)} s';
