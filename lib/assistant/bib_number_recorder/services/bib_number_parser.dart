import 'package:xceleration/core/utils/logger.dart';

/// Maps recognised number words to their integer values.
///
/// Includes common ASR misrecognitions:
/// - "a" → 1 (model outputs "a hundred" for "one hundred")
/// - "for" → 4 (model confuses "four" with "for")
/// - "oh" → 0 (common spoken synonym for zero)
const Map<String, int> _wordValues = {
  'zero': 0, 'oh': 0, 'o': 0, 'ow': 0,
  'one': 1, 'a': 1, 'two': 2, 'to': 2, 'three': 3, 'four': 4, 'for': 4,
  'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
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
  'dire', 'dieu', 'youm', 'yeob', 'vour', 'vor', 'erro', 'edy',
  'ows', 'owen', 'tuzo', 'monso',
};

/// Detects garbled "zero" output from the model.
///
/// Unrecognised words containing z, g, or multiple s's are almost always
/// mangled zeros. Length determines whether one or two zeros were merged:
/// - Short (2–6 chars): single zero  (e.g. "zer", "zio", "giro")
/// - Long  (7+ chars):  double zero  (e.g. "zerosio", "girozier", "geosiosio")
String? _garbledZeroReplacement(String word) {
  if (_wordValues.containsKey(word)) return null;
  if (word.length < 2) return null;

  final hasZ = word.contains('z');
  final hasG = word.contains('g');
  final sCount = 's'.allMatches(word).length;

  if (!hasZ && !hasG && sCount < 2) return null;

  return word.length >= 7 ? 'zero zero' : 'zero';
}

/// Words that may be "zero" but are also real English words.
/// Only substituted as a fallback when the transcript otherwise fails to parse.
const Set<String> _ambiguousZeroWords = {
  'year', "year's", 'years', 'europe', 'now', 'x', 'u',
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

    final words = rawWords.where((w) => w.isNotEmpty && w != 'and').toList();
    Logger.d('[BibParser] After filtering empty/"and": $words');

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
      } else if (pendingTens != null) {
        final combined = _wordValues[pendingTens]! + v;
        chunks.add(combined);
        Logger.d('[BibParser:chunked] "$word" → value=$v combined with pending "$pendingTens" (${_wordValues[pendingTens]}) = $combined  chunks=$chunks');
        pendingTens = null;
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
    final joined = chunks.map((c) => c.toString()).join();
    Logger.d('[BibParser:chunked] Chunks: $chunks → joined: "$joined"');

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
