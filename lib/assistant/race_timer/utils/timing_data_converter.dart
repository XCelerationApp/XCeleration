import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import 'dart:math';
import '../../../core/utils/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../model/ui_record.dart';


/// Utility class for converting TimingDatum records to UIRecord objects
class TimingDataConverter {
  static ConversionCache? _cache;

  /// Main conversion method - converts TimingDatum records to UIRecord objects
  static List<UIRecord> convertToUIRecords(List<TimingDatum> records) {
    if (records.isEmpty) return [];

    // Check if we can use cached result
    if (_cache != null &&
        !_hasSignificantChanges(_cache!.lastRecords, records)) {
      return _cache!.lastUIRecords;
    }

    // Perform full conversion
    final uiRecords = _performFullConversion(records);

    // Update cache
    _cache = ConversionCache(
      lastRecords: List.from(records),
      lastUIRecords: uiRecords,
      lastConversion: DateTime.now(),
    );

    return uiRecords;
  }

  /// Detect if records have changed significantly enough to require reconversion
  static bool _hasSignificantChanges(
      List<TimingDatum> oldRecords, List<TimingDatum> newRecords) {
    // Compare record counts
    if (oldRecords.length != newRecords.length) return true;

    // Check for conflict changes
    final oldConflicts = oldRecords.where((r) => r.conflict != null).length;
    final newConflicts = newRecords.where((r) => r.conflict != null).length;
    if (oldConflicts != newConflicts) return true;

    // Check for type changes in last few records
    final checkCount = min(3, oldRecords.length);
    for (int i = 0; i < checkCount; i++) {
      final oldIndex = oldRecords.length - 1 - i;
      final newIndex = newRecords.length - 1 - i;
      if (oldIndex >= 0 && newIndex >= 0) {
        if (oldRecords[oldIndex].conflict?.type !=
            newRecords[newIndex].conflict?.type) {
          return true;
        }
      }
    }

    return false;
  }

  /// Perform the full conversion from TimingDatum to UIRecord
  static List<UIRecord> _performFullConversion(List<TimingDatum> records) {
    final List<UIRecord> uiRecords = [];
    int currentPlace = 1;
    bool inConflictArea = false;
    Conflict? activeConflict;

    for (int i = 0; i < records.length; i++) {
      final datum = records[i];

      // Check if this record has a conflict that changes our state
      if (datum.conflict != null) {
        activeConflict = datum.conflict;

        if (datum.conflict!.type == ConflictType.confirmRunner) {
          // Confirm all previous runner time records
          _markPreviousRecordsAsConfirmed(uiRecords);
          inConflictArea = false;
        } else {
          // Start conflict area
          inConflictArea = true;

          // Handle missing time conflicts by adding placeholder records
          if (datum.conflict!.type == ConflictType.missingTime) {
            final missingRecords = _createMissingTimeRecords(
                datum.conflict!.offBy, currentPlace, i);
            uiRecords.addAll(missingRecords);
            currentPlace += datum.conflict!.offBy;
          }
        }
      }

      // Determine record type
      RecordType recordType;
      if (datum.conflict?.type == ConflictType.confirmRunner) {
        recordType = RecordType.confirmRunner;
      } else if (datum.conflict?.type == ConflictType.missingTime) {
        recordType = RecordType.missingTime;
      } else if (datum.conflict?.type == ConflictType.extraTime) {
        recordType = RecordType.extraTime;
      } else {
        recordType = RecordType.runnerTime;
      }

      // Create UI record
      final uiRecord = UIRecord(
        time: datum.time,
        place: recordType == RecordType.runnerTime ? currentPlace : null,
        textColor: _determineTextColor(datum, inConflictArea, activeConflict),
        type: recordType,
        conflict: datum.conflict,
        index: i, // This is the original TimingDatum index
        isConfirmed: !inConflictArea &&
            datum.conflict?.type == ConflictType.confirmRunner,
      );

      uiRecords.add(uiRecord);

      // Increment place for runner time records
      if (recordType == RecordType.runnerTime) {
        currentPlace++;
      }
    }

    return uiRecords;
  }

  /// Create placeholder records for missing times
  static List<UIRecord> _createMissingTimeRecords(
      int offBy, int startPlace, int baseIndex) {
    final List<UIRecord> missingRecords = [];

    for (int i = 0; i < offBy; i++) {
      missingRecords.add(UIRecord(
        time: 'TBD',
        place: startPlace + i,
        textColor: AppColors.redColor,
        type: RecordType.runnerTime,
        conflict: Conflict(type: ConflictType.missingTime, offBy: offBy),
        index: -1, // Mark as synthetic record with -1 index
        isConfirmed: false,
      ));
    }

    return missingRecords;
  }

  /// Mark all previous runner time records as confirmed
  static void _markPreviousRecordsAsConfirmed(List<UIRecord> uiRecords) {
    for (int i = uiRecords.length - 1; i >= 0; i--) {
      if (uiRecords[i].type == RecordType.runnerTime) {
        uiRecords[i] = UIRecord(
          time: uiRecords[i].time,
          place: uiRecords[i].place,
          textColor: Colors.green,
          type: uiRecords[i].type,
          conflict: uiRecords[i].conflict,
          index: uiRecords[i].index,
          isConfirmed: true,
        );
      } else {
        break; // Stop at first non-runner time record
      }
    }
  }

  /// Determine the text color based on record state and conflicts
  static Color _determineTextColor(
      TimingDatum datum, bool inConflictArea, Conflict? activeConflict) {
    // If record has a confirm conflict, it's green
    if (datum.conflict?.type == ConflictType.confirmRunner) {
      return Colors.green;
    }

    // If record has a conflict (missing/extra time), it's red
    if (datum.conflict?.type == ConflictType.missingTime ||
        datum.conflict?.type == ConflictType.extraTime) {
      return AppColors.redColor;
    }

    // If we're in a conflict area, use red
    if (inConflictArea) {
      return AppColors.redColor;
    }

    // Default color for unconfirmed records
    return Colors.black;
  }

  /// Clear the conversion cache (useful for testing or manual cache invalidation)
  static void clearCache() {
    _cache = null;
  }
}
