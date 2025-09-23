import 'package:flutter/material.dart';
// import 'package:xceleration/coach/merge_conflicts/model/timing_data.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'enums.dart';
import '../components/dialog_utils.dart';

class BibDecodeUtils {
  /// Decodes encoded runner data
  static Future<List<BibDatum>?> decodeEncodedRunners(
      String encodedBibData, BuildContext context) async {
    try {
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
