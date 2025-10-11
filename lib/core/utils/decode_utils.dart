import 'package:flutter/material.dart';
// import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'enums.dart';
import '../components/dialog_utils.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Returns the unwrapped string if input is gzip+base64, otherwise returns input as-is
String _maybeUnwrapGzipBase64(String input) {
  try {
    // Fast path: reject obviously too short inputs
    if (input.length < 8) return input;
    final Uint8List b = base64Decode(input);
    // Check gzip header 0x1f 0x8b
    if (b.length >= 2 && b[0] == 0x1f && b[1] == 0x8b) {
      final decoded = gzip.decode(b);
      return utf8.decode(decoded);
    }
  } catch (_) {
    // Not base64 or not gzip — fall through
  }
  return input;
}

class BibDecodeUtils {
  /// Decodes encoded runner data
  static Future<List<BibDatum>?> decodeEncodedRunners(
      String encodedBibData, BuildContext context) async {
    try {
      // Backward-compatible: support gzip+base64 wrapped payloads
      encodedBibData = _maybeUnwrapGzipBase64(encodedBibData);
      // Try compact JSON (BIB_SHARE_V2)
      try {
        final dynamic parsed = jsonDecode(encodedBibData);
        if (parsed is Map<String, dynamic> &&
            parsed['type'] == 'BIB_SHARE_V2') {
          final List<dynamic> teamsList =
              (parsed['teams'] as List?) ?? const [];
          final List<dynamic> rows = (parsed['r'] as List?) ?? const [];
          final List<String> teams =
              teamsList.map((e) => e?.toString() ?? '').toList();
          final List<BibDatum> bibs = [];
          for (final row in rows) {
            if (row is List && row.length >= 4) {
              final String bib = row[0]?.toString() ?? '';
              final String name = row[1]?.toString() ?? '';
              final int? tIdx = row[2] is num ? (row[2] as num).toInt() : null;
              final String grade = row[3]?.toString() ?? '';
              final String? teamAbbrev =
                  (tIdx != null && tIdx >= 0 && tIdx < teams.length)
                      ? (teams[tIdx].isNotEmpty ? teams[tIdx] : null)
                      : null;
              bibs.add(BibDatum(
                bib: bib,
                name: name.isNotEmpty ? name : null,
                teamAbbreviation: teamAbbrev,
                grade: grade.isNotEmpty ? grade : null,
              ));
            }
          }
          return bibs;
        }
      } catch (_) {
        // Not JSON; fall through to legacy parsing
      }

      // Legacy format: space-delimited tokens; each token can be a CSV BibDatum
      // Parallelize the decoding operations
      final futures = encodedBibData.split(' ').map((encodedBibDatum) async {
        encodedBibDatum = encodedBibDatum.trim();
        if (encodedBibDatum.isEmpty) {
          return null;
        }
        try {
          return BibDatum.fromEncodedString(encodedBibDatum);
        } catch (e) {
          Logger.d('Error processing bib data: $e');
          return null;
        }
      });

      final results = await Future.wait(futures);
      return results
          .where((result) => result != null)
          .cast<BibDatum>()
          .toList();
    } catch (e) {
      Logger.e('Error processing data: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context,
            message: 'Error processing data: $e');
      }
      return null;
    }
  }
}

/// Helper class for conflict parsing
class ConflictInfo {
  final RecordType type;
  final int offBy;
  final String time;

  ConflictInfo({required this.type, required this.offBy, required this.time});
}

class TimingDecodeUtils {
  /// Decodes a string of race times into TimingData
  static Future<List<TimingDatum>> decodeEncodedTimingData(
      String encodedTimingData) async {
    if (encodedTimingData.isEmpty) {
      return [];
    }

    // Backward-compatible: support gzip+base64 wrapped payloads
    encodedTimingData = _maybeUnwrapGzipBase64(encodedTimingData);

    // Parallelize the decoding operations
    final futures =
        encodedTimingData.split(',').map((encodedTimingDatum) async {
      encodedTimingDatum = encodedTimingDatum.trim();
      if (encodedTimingDatum.isEmpty) {
        return null;
      }
      try {
        return TimingDatum.fromEncodedString(encodedTimingDatum);
      } catch (e) {
        Logger.d('Error processing timing datum: $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    return results
        .where((result) => result != null)
        .cast<TimingDatum>()
        .toList();
  }
}
