/// Who a mistyped bib most likely was, worked out the way a coach would:
/// the runners not placed yet whose bib is one slip of the thumb away, and
/// failing that, the runners on the team whose bibs the typed one falls
/// among (each school's bibs usually run in a block).
library;

import 'package:xceleration/shared/models/database/race_runner.dart';

/// A runner the typed bib might have been, and why.
class RunnerSuggestion {
  const RunnerSuggestion({required this.runner, required this.reasons});

  final RaceRunner runner;

  /// Short reasons, most telling first, e.g. "Two digits swapped".
  final List<String> reasons;
}

/// Up to [limit] runners from [free] (those not placed yet) that [typed]
/// was most likely meant to be. [roster] is everyone in the race, for each
/// team's block of bibs.
List<RunnerSuggestion> suggestRunnersForBib(
  String typed, {
  required List<RaceRunner> free,
  required List<RaceRunner> roster,
  int limit = 3,
}) {
  typed = typed.trim();
  final typedValue = int.tryParse(typed);
  if (typed.isEmpty) return const [];

  final blocks = teamBibBlocks(roster);
  String? blockOf(RaceRunner r) {
    final team = r.team.name;
    final block = team == null ? null : blocks[team];
    if (block == null || typedValue == null) return null;
    final (low, high) = block;
    if (typedValue < low || typedValue > high) return null;
    return 'Among $team\'s bibs ($low–$high)';
  }

  final close = <(RunnerSuggestion, int)>[];
  final sameBlock = <(RunnerSuggestion, int)>[];
  for (final runner in free) {
    final bib = runner.runner.bibNumber?.trim() ?? '';
    if (bib.isEmpty || bib == typed) continue;
    final slip = bibSlip(typed, bib);
    final block = blockOf(runner);
    // Nearest number first, among bibs of the same length; a digit more or
    // less makes the numbers far apart but the slip just as likely.
    final distance = typedValue == null || bib.length != typed.length
        ? 0
        : ((int.tryParse(bib) ?? 1 << 30) - typedValue).abs();
    final reasons = [?slip, ?block, 'Not placed yet'];
    if (slip != null) {
      close.add((RunnerSuggestion(runner: runner, reasons: reasons), distance));
    } else if (block != null) {
      sameBlock
          .add((RunnerSuggestion(runner: runner, reasons: reasons), distance));
    }
  }

  // A runner in the right block counts for more than one elsewhere; then
  // the nearest bib number.
  int byLikelihood((RunnerSuggestion, int) a, (RunnerSuggestion, int) b) {
    final aBlock = a.$1.reasons.length;
    final bBlock = b.$1.reasons.length;
    if (aBlock != bBlock) return bBlock.compareTo(aBlock);
    return a.$2.compareTo(b.$2);
  }

  close.sort(byLikelihood);
  sameBlock.sort(byLikelihood);
  return [
    for (final (s, _) in [...close, ...sameBlock].take(limit)) s,
  ];
}

/// How [typed] could be a slip for [bib], or null if it is more than one
/// slip away: one digit different, two neighbouring digits swapped, a digit
/// left out or one too many.
String? bibSlip(String typed, String bib) {
  if (typed.length == bib.length) {
    final diffs = [
      for (var i = 0; i < typed.length; i++)
        if (typed[i] != bib[i]) i,
    ];
    if (diffs.length == 1) return 'One digit different';
    if (diffs.length == 2 &&
        diffs[1] == diffs[0] + 1 &&
        typed[diffs[0]] == bib[diffs[1]] &&
        typed[diffs[1]] == bib[diffs[0]]) {
      return 'Two digits swapped';
    }
    return null;
  }
  if (typed.length == bib.length - 1 && _dropsOne(bib, typed)) {
    return 'A digit left out';
  }
  if (typed.length == bib.length + 1 && _dropsOne(typed, bib)) {
    return 'One digit too many';
  }
  return null;
}

/// Whether removing one character from [longer] gives [shorter].
bool _dropsOne(String longer, String shorter) {
  for (var i = 0; i < longer.length; i++) {
    if (longer.substring(0, i) + longer.substring(i + 1) == shorter) {
      return true;
    }
  }
  return false;
}

/// Each team's lowest and highest numeric bib, by team name.
Map<String, (int, int)> teamBibBlocks(List<RaceRunner> roster) {
  final blocks = <String, (int, int)>{};
  for (final r in roster) {
    final team = r.team.name;
    final value = int.tryParse(r.runner.bibNumber ?? '');
    if (team == null || value == null) continue;
    final current = blocks[team];
    blocks[team] = current == null
        ? (value, value)
        : (value < current.$1 ? value : current.$1,
            value > current.$2 ? value : current.$2);
  }
  return blocks;
}
