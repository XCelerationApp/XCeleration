/// Finds runners by a name typed in a hurry, for settling a bib conflict:
/// part of a first or last name, either order, and a slip or two of the
/// thumb ("jonh smtih" still finds John Smith). A bib number works too.
library;

/// How well [query] matches a runner called [name] with [bib], from 0 (not
/// at all) to 1, or null when it does not match.
double? runnerMatchScore(String query, {required String name, String? bib}) {
  final q = _normalise(query);
  if (q.isEmpty) return null;

  // A number is a bib: exact first, then bibs that start with it.
  if (RegExp(r'^\d+$').hasMatch(q)) {
    if (bib == null || bib.isEmpty) return null;
    if (bib == q) return 1;
    if (bib.startsWith(q)) return 0.8;
    return null;
  }

  final nameWords = _normalise(name).split(' ').where((w) => w.isNotEmpty);
  if (nameWords.isEmpty) return null;
  final queryWords = q.split(' ').where((w) => w.isNotEmpty).toList();

  // Every word typed has to match some word of the name.
  var total = 0.0;
  for (final word in queryWords) {
    var best = 0.0;
    for (final part in nameWords) {
      final score = _wordScore(word, part);
      if (score > best) best = score;
    }
    if (best == 0) return null;
    total += best;
  }
  return total / queryWords.length;
}

/// The runners matching [query], best first, at most [limit] of them.
List<T> searchRunners<T>(
  Iterable<T> runners,
  String query, {
  required String Function(T) nameOf,
  required String? Function(T) bibOf,
  int limit = 8,
}) {
  final scored = <(T, double)>[];
  for (final runner in runners) {
    final score =
        runnerMatchScore(query, name: nameOf(runner), bib: bibOf(runner));
    if (score != null) scored.add((runner, score));
  }
  // Stable: equal scores keep the order they came in.
  final indexed = scored.indexed.toList()
    ..sort((a, b) {
      final byScore = b.$2.$2.compareTo(a.$2.$2);
      return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
    });
  return [for (final (_, (runner, _)) in indexed.take(limit)) runner];
}

double _wordScore(String typed, String word) {
  if (typed == word) return 1;
  if (word.startsWith(typed)) return 0.9;
  if (typed.length >= 3 && word.contains(typed)) return 0.7;
  // Typos: one slip in a short word, two in a longer one.
  if (typed.length >= 3) {
    final distance = _editDistance(typed, word);
    if (distance <= 1) return 0.6;
    if (distance <= 2 && typed.length >= 5) return 0.45;
    // A typo within what has been typed so far ("jonh" for "johnathan").
    if (word.length > typed.length &&
        _editDistance(typed, word.substring(0, typed.length)) <= 1) {
      return 0.5;
    }
  }
  return 0;
}

String _normalise(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Damerau–Levenshtein distance (a swap of two letters counts as one slip).
int _editDistance(String a, String b) {
  final rows = a.length + 1, cols = b.length + 1;
  final d = List.generate(rows, (i) => List<int>.filled(cols, 0));
  for (var i = 0; i < rows; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j < cols; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var v = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1]) {
        v = v < d[i - 2][j - 2] + 1 ? v : d[i - 2][j - 2] + 1;
      }
      d[i][j] = v;
    }
  }
  return d[a.length][b.length];
}
