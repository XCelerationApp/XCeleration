import 'package:xceleration/core/utils/logger.dart';

/// Maps recognised number words to their integer values.
///
/// Includes common ASR misrecognitions:
/// - "a" → 1 (model outputs "a hundred" for "one hundred")
/// - "for" → 4 (model confuses "four" with "for")
/// - "oh" → 0 (common spoken synonym for zero)
const Map<String, int> _wordValues = {
  'zero': 0, 'oh': 0, 'o': 0, 'ow': 0,
  'one': 1, 'a': 1, 'won': 1, 'n': 1,
  'two': 2, 'to': 2, 'too': 2, 'three': 3, 'four': 4, 'for': 4,
  'five': 5, 'six': 6, 'zic': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
  'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
  'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
  'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
  'eighty': 80, 'ninety': 90,
};

/// Words the model commonly produces instead of "zero".
///
/// Collected from on-device testing. Only includes words that are not valid
/// English number words, so substitution is always safe.
/// Unrecognised words that should always map to zero but don't match the
/// z/g/ss heuristic (e.g. short words with none of those characters).
const Set<String> _zeroSubstitutions = {
  'dire', 'dieu', 'youm', 'yeob', 'vour', 'vor', 'erro', 'ero', 'edy',
  'er', 'ere', 'yo',
  'ows', 'owen', 'owve', 'tuzo', 'monso',
};

/// Words that a garbled-zero candidate might actually be.
/// If the candidate is within edit distance 2 of any of these, it's not zero.
const List<String> _nonZeroNumberWords = [
  'six', 'seven', 'eight', 'nine', 'sixty', 'seventy', 'eighty',
  'ninety', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
];

/// Detects garbled "zero" output from the model.
///
/// Unrecognised words containing z, g, or multiple s's are almost always
/// mangled zeros. Length determines whether one or two zeros were merged:
/// - Short (2–6 chars): single zero  (e.g. "zer", "zio", "giro")
/// - Long  (7+ chars):  double zero  (e.g. "zerosio", "girozier", "geosiosio")
///
/// Excludes words that are close to known number words (e.g. "zic" ≈ "six").
String? _garbledZeroReplacement(String word) {
  if (_wordValues.containsKey(word)) return null;
  if (word.length < 2) return null;

  final hasZ = word.contains('z');
  final hasG = word.contains('g');
  final sCount = 's'.allMatches(word).length;

  if (!hasZ && !hasG && sCount < 2) return null;

  // Don't treat as zero if it's close to a real number word.
  for (final nw in _nonZeroNumberWords) {
    if (_editDistance(word, nw) <= 1) return null;
  }

  return word.length >= 7 ? 'zero zero' : 'zero';
}

/// Levenshtein edit distance between two strings.
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final prev = List<int>.generate(b.length + 1, (i) => i);
  final curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
          .reduce((a, b) => a < b ? a : b);
    }
    prev.setAll(0, curr);
  }
  return curr[b.length];
}

/// Words that may be "zero" but are also real English words.
/// Only substituted as a fallback when the transcript otherwise fails to parse.
const Set<String> _ambiguousZeroWords = {
  'year', "year's", 'years', 'europe', 'now', 'x', 'u', 'y', 'or',
};

/// Converts spoken number-word sequences into bib number strings.
///
/// Injectable so callers can mock or replace the parsing logic.
///
/// Three input forms are supported:
/// - Digit-by-digit: "one two three four" → "1234"
/// - Chunked:        "twelve thirty four" → "1234"
/// - Natural English: "one thousand two hundred and thirty four" → "1234"
///
/// Returns a digit string preserving leading zeros (e.g. "0001").
class BibNumberParser {
  const BibNumberParser();

  /// Returns the parsed bib number as a string (preserving leading zeros),
  /// or null if the text cannot be parsed or falls outside 0–9999.
  String? parse(String text) {
    Logger.d('[BibParser] Input text: "$text"');

    if (text.isEmpty) {
      Logger.d('[BibParser] Empty input → null');
      return null;
    }

    // Strip possessive suffixes the model sometimes adds ("eleven's" → "eleven").
    final stripped = _stripPossessives(text);
    if (stripped != text) {
      Logger.d('[BibParser] After possessive stripping: "$stripped"');
    }

    // First pass: try with safe zero substitutions applied.
    final normalised = _normaliseZeros(stripped);
    if (normalised != text) {
      Logger.d('[BibParser] After zero normalisation: "$normalised"');
    }

    final result = _tryParse(normalised);
    if (result != null) return result;

    // Second pass: also substitute ambiguous words (year, etc.) if the first
    // parse failed — these are only safe when no other interpretation works.
    final aggressive = _normaliseAmbiguousZeros(normalised);
    if (aggressive != normalised) {
      Logger.d('[BibParser] Retrying with ambiguous zero substitutions: "$aggressive"');
      return _tryParse(aggressive);
    }

    return null;
  }

  String? _tryParse(String text) {
    final rawWords = text.split(RegExp(r'\s+'));
    Logger.d('[BibParser] Raw words: $rawWords');

    var words = rawWords.where((w) => w.isNotEmpty && w != 'and').toList();

    // Strip spurious "a" when followed by a number word (not hundred/thousand).
    // Handles "a one hundred" → "one hundred" while preserving "a hundred".
    words = _filterSpuriousA(words);

    Logger.d('[BibParser] After filtering: $words');

    if (words.isEmpty) {
      Logger.d('[BibParser] No words remain → null');
      return null;
    }

    // Check for unrecognised words before choosing strategy
    final unrecognised = words
        .where((w) => w != 'hundred' && w != 'thousand' && !_wordValues.containsKey(w))
        .toList();
    if (unrecognised.isNotEmpty) {
      Logger.d('[BibParser] Unrecognised words: $unrecognised → null');
      return null;
    }

    if (words.contains('hundred') || words.contains('thousand')) {
      Logger.d('[BibParser] Strategy: _parseNatural (contains hundred/thousand)');
      final result = _parseNatural(words);
      Logger.d('[BibParser] Final result: $result');
      return result;
    }
    Logger.d('[BibParser] Strategy: _parseChunked');
    final result = _parseChunked(words);
    Logger.d('[BibParser] Final result: $result');
    return result;
  }

  String? _parseNatural(List<String> words) {
    int result = 0;
    int current = 0;
    for (final word in words) {
      if (word == 'thousand') {
        final multiplier = current == 0 ? 1 : current;
        result += multiplier * 1000;
        Logger.d('[BibParser:natural] "$word" → result += $multiplier*1000 = ${multiplier * 1000}  (result=$result, current reset to 0)');
        current = 0;
      } else if (word == 'hundred') {
        final multiplier = current == 0 ? 1 : current;
        current = multiplier * 100;
        Logger.d('[BibParser:natural] "$word" → current = $multiplier*100 = $current  (result=$result)');
      } else {
        final v = _wordValues[word];
        if (v == null) {
          Logger.d('[BibParser:natural] "$word" → unrecognised → null');
          return null;
        }
        current += v;
        Logger.d('[BibParser:natural] "$word" → value=$v  (current=$current, result=$result)');
      }
    }
    result += current;
    Logger.d('[BibParser:natural] Final: result=$result (valid range 1–9999: ${result >= 1 && result <= 9999})');
    if (result < 1 || result > 9999) return null;
    return result.toString();
  }

  String? _parseChunked(List<String> words) {
    final chunks = <int>[];
    String? pendingTens;

    for (final word in words) {
      final v = _wordValues[word];
      if (v == null) {
        Logger.d('[BibParser:chunked] "$word" → unrecognised → null');
        return null;
      }

      if (v >= 20 && v % 10 == 0) {
        if (pendingTens != null) {
          chunks.add(_wordValues[pendingTens]!);
          Logger.d('[BibParser:chunked] "$word" is tens → flushing pending "$pendingTens" as ${_wordValues[pendingTens]}  chunks=$chunks');
        }
        pendingTens = word;
        Logger.d('[BibParser:chunked] "$word" → value=$v (tens, held as pending)');
      } else if (pendingTens != null && v < 10) {
        // Only combine single digits (0–9) with a pending tens word.
        // Values ≥ 10 (ten, eleven, twelve, etc.) start a new chunk.
        final combined = _wordValues[pendingTens]! + v;
        chunks.add(combined);
        Logger.d('[BibParser:chunked] "$word" → value=$v combined with pending "$pendingTens" (${_wordValues[pendingTens]}) = $combined  chunks=$chunks');
        pendingTens = null;
      } else if (pendingTens != null) {
        // Flush the pending tens as its own chunk, then add this value.
        chunks.add(_wordValues[pendingTens]!);
        Logger.d('[BibParser:chunked] "$word" (value=$v ≥10) → flushing pending "$pendingTens" as ${_wordValues[pendingTens]}  chunks=$chunks');
        pendingTens = null;
        chunks.add(v);
        Logger.d('[BibParser:chunked] "$word" → value=$v  chunks=$chunks');
      } else {
        chunks.add(v);
        Logger.d('[BibParser:chunked] "$word" → value=$v  chunks=$chunks');
      }
    }

    if (pendingTens != null) {
      chunks.add(_wordValues[pendingTens]!);
      Logger.d('[BibParser:chunked] Flushing final pending "$pendingTens" as ${_wordValues[pendingTens]}  chunks=$chunks');
    }

    if (chunks.isEmpty) {
      Logger.d('[BibParser:chunked] No chunks produced → null');
      return null;
    }

    // Concatenate chunk digit strings — this preserves leading zeros.
    var joined = chunks.map((c) => c.toString()).join();
    Logger.d('[BibParser:chunked] Chunks: $chunks → joined: "$joined"');

    // If too many digits (common when fuzzy-zero adds an extra zero the model
    // already transcribed), try removing one zero-valued chunk and re-joining.
    if (joined.length > 4 && chunks.contains(0)) {
      final trimmed = List<int>.from(chunks);
      trimmed.remove(0); // removes first zero
      final rejoin = trimmed.map((c) => c.toString()).join();
      if (rejoin.length <= 4) {
        Logger.d('[BibParser:chunked] Overflow "$joined" → dropped one zero → "$rejoin"');
        joined = rejoin;
      }
    }

    if (joined.length > 4) return null;
    final intValue = int.tryParse(joined);
    if (intValue == null || intValue < 1 || intValue > 9999) return null;
    return joined;
  }

  /// Replaces known zero-misrecognitions with "zero".
  static String _normaliseZeros(String text) {
    final words = text.split(RegExp(r'\s+'));
    var changed = false;
    final result = words.map((w) {
      final zReplace = _garbledZeroReplacement(w);
      if (_zeroSubstitutions.contains(w) || zReplace != null) {
        changed = true;
        return zReplace ?? 'zero';
      }
      return w;
    }).toList();
    return changed ? result.join(' ') : text;
  }

  /// Removes "a" when it appears before a number word that isn't "hundred" or
  /// "thousand". Handles model output like "a one hundred" → "one hundred".
  static List<String> _filterSpuriousA(List<String> words) {
    final result = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (words[i] == 'a' &&
          i + 1 < words.length &&
          words[i + 1] != 'hundred' &&
          words[i + 1] != 'thousand' &&
          _wordValues.containsKey(words[i + 1])) {
        continue; // skip this "a"
      }
      result.add(words[i]);
    }
    return result;
  }

  /// Strips possessive suffixes the model sometimes adds (e.g. "eleven's" → "eleven").
  static String _stripPossessives(String text) {
    final words = text.split(RegExp(r'\s+'));
    var changed = false;
    final result = words.map((w) {
      if (w.endsWith("'s")) {
        changed = true;
        return w.substring(0, w.length - 2);
      }
      return w;
    }).toList();
    return changed ? result.join(' ') : text;
  }

  /// Replaces ambiguous words (year, etc.) with "zero" — only used as a
  /// fallback when the first parse fails.
  static String _normaliseAmbiguousZeros(String text) {
    final words = text.split(RegExp(r'\s+'));
    var changed = false;
    final result = words.map((w) {
      if (_ambiguousZeroWords.contains(w)) {
        changed = true;
        return 'zero';
      }
      return w;
    }).toList();
    return changed ? result.join(' ') : text;
  }
}
