import 'package:xceleration/assistant/shared/models/runner.dart';

/// Pure-Dart phonetic search utility used by [FixerController].
///
/// Scores a [Runner] against a query string using three signals, returning
/// the highest signal found:
///
/// | Score | Signal |
/// |-------|--------|
/// | 1.0   | Exact bib match |
/// | 0.9   | Exact name match (case-insensitive) |
/// | 0.8   | Query is substring of name or bib |
/// | 0.5   | Any query token is a substring of any name token (or vice-versa) |
/// | 0.4   | Any query token shares a Soundex code with any name token |
///
/// A score of 0 means no meaningful match — the controller excludes these.
class PhoneticSearch {
  const PhoneticSearch._();

  /// Returns a relevance score in [0, 1] for [runner] against [query].
  ///
  /// Returns 0 if the query is blank or nothing matches.
  static double score(String query, Runner runner) {
    final q = query.trim();
    if (q.isEmpty) return 0;

    final qLower = q.toLowerCase();
    final bib = runner.bibNumber.toLowerCase();

    // Exact bib match
    if (bib == qLower) return 1.0;

    // Bib substring
    if (bib.contains(qLower)) return 0.8;

    final name = runner.name;
    if (name == null || name.isEmpty) return 0;
    final nameLower = name.toLowerCase();

    // Exact name match
    if (nameLower == qLower) return 0.9;

    // Full-query substring of name
    if (nameLower.contains(qLower)) return 0.8;

    // Token-level matching
    final queryTokens = qLower
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final nameTokens = nameLower
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    double best = 0;
    for (final qt in queryTokens) {
      for (final nt in nameTokens) {
        if (nt.contains(qt) || qt.contains(nt)) {
          if (best < 0.5) best = 0.5;
        } else if (soundex(qt) == soundex(nt)) {
          if (best < 0.4) best = 0.4;
        }
      }
    }
    return best;
  }

  /// Standard 4-character Soundex encoding for [s].
  ///
  /// Returns an empty string if [s] contains no alphabetic characters.
  static String soundex(String s) {
    if (s.isEmpty) return '';

    const Map<String, String> table = {
      'b': '1', 'f': '1', 'p': '1', 'v': '1',
      'c': '2', 'g': '2', 'j': '2', 'k': '2',
      'q': '2', 's': '2', 'x': '2', 'z': '2',
      'd': '3', 't': '3',
      'l': '4',
      'm': '5', 'n': '5',
      'r': '6',
    };

    final chars = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (chars.isEmpty) return '';

    final first = chars[0].toUpperCase();
    final buffer = StringBuffer(first);
    String prev = table[chars[0]] ?? '0';

    for (int i = 1; i < chars.length; i++) {
      final code = table[chars[i]] ?? '0';
      if (code != '0' && code != prev) {
        buffer.write(code);
        if (buffer.length == 4) break;
      }
      prev = code;
    }

    while (buffer.length < 4) {
      buffer.write('0');
    }

    return buffer.toString();
  }
}
