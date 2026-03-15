/// Maps recognised number words to their integer values.
const Map<String, int> _wordValues = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
  'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13,
  'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
  'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30,
  'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70,
  'eighty': 80, 'ninety': 90,
};

/// Converts spoken number-word sequences into integers in the range 1–9999.
///
/// Injectable so callers can mock or replace the parsing logic.
///
/// Three input forms are supported:
/// - Digit-by-digit: "one two three four" → 1234
/// - Chunked:        "twelve thirty four" → 1234
/// - Natural English: "one thousand two hundred and thirty four" → 1234
class BibNumberParser {
  const BibNumberParser();

  /// Returns the parsed bib number, or null if the text cannot be parsed or
  /// falls outside the valid range 1–9999.
  int? parse(String text) {
    if (text.isEmpty) return null;

    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w != 'and')
        .toList();

    if (words.isEmpty) return null;

    if (words.contains('hundred') || words.contains('thousand')) {
      return _parseNatural(words);
    }
    return _parseChunked(words);
  }

  int? _parseNatural(List<String> words) {
    int result = 0;
    int current = 0;
    for (final word in words) {
      if (word == 'thousand') {
        result += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else if (word == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
      } else {
        final v = _wordValues[word];
        if (v == null) return null;
        current += v;
      }
    }
    result += current;
    if (result < 1 || result > 9999) return null;
    return result;
  }

  int? _parseChunked(List<String> words) {
    final chunks = <int>[];
    String? pendingTens;

    for (final word in words) {
      final v = _wordValues[word];
      if (v == null) return null;

      if (v >= 20 && v % 10 == 0) {
        if (pendingTens != null) chunks.add(_wordValues[pendingTens]!);
        pendingTens = word;
      } else if (pendingTens != null) {
        chunks.add(_wordValues[pendingTens]! + v);
        pendingTens = null;
      } else {
        chunks.add(v);
      }
    }

    if (pendingTens != null) chunks.add(_wordValues[pendingTens]!);
    if (chunks.isEmpty) return null;

    final joined = chunks.map((c) => c.toString()).join();
    final result = int.tryParse(joined);
    if (result == null || result < 1 || result > 9999) return null;
    return result;
  }
}
