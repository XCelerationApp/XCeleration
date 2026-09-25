import 'dart:convert';
import 'dart:io';

/// Decodes an encoded race payload and returns the inner race metadata map.
///
/// This is a top-level function so it can be passed to [compute].
Map<String, dynamic> decodeRaceMap(String encodedPayload) {
  final decoded = utf8.decode(gzip.decode(base64Decode(encodedPayload)));
  final map = jsonDecode(decoded) as Map<String, dynamic>;
  return map['race'] as Map<String, dynamic>;
}
