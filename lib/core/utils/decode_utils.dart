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

/// Decodes and decompresses a gzip+base64 encoded string
String decodeAndDecompress(String input) {
  final Uint8List compressed = base64Decode(input);
  final decompressed = gzip.decode(compressed);
  return utf8.decode(decompressed);
}

class BibDecodeUtils {
  /// Decodes encoded runner data
  static Future<List<BibDatum>?> decodeEncodedRunners(
      String encodedBibData, BuildContext context) async {
    try {
      // Decompress the gzip+base64 encoded data
      final decompressed = decodeAndDecompress(encodedBibData);

      // Parse compact JSON format
      final dynamic parsed = jsonDecode(decompressed);
      if (parsed is! Map<String, dynamic>) {
        throw FormatException('Invalid bib data format');
      }

      final List<dynamic> teamsList = (parsed['teams'] as List?) ?? const [];
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
      String encodedTimingData,
      {bool isFromDatabase = false}) async {
    if (encodedTimingData.isEmpty) {
      return [];
    }
    final String decompressed = isFromDatabase
        ? encodedTimingData
        : decodeAndDecompress(encodedTimingData);

    // Parallelize the decoding operations
    final futures = decompressed.split(',').map((encodedTimingDatum) async {
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
