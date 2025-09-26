import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../../core/utils/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../model/ui_record.dart';

/// Utility class for converting TimingDatum records to UIRecord objects
class TimingDataConverter {
  final Map<TimingChunk, UIRecord> _cachedRecords = {};

  /// Main conversion method - converts TimingDatum records to UIRecord objects
  static UIChunk convertToUIChunk(TimingChunk chunk, startingPlace) {
    final List<UIRecord> uiRecords = [];
    int endingPlace = startingPlace;
    if (chunk.isEmpty) {
      // do nothing, will return an empty UIChunk
    } else if (!chunk.hasConflict) {
      for (int i = 0; i < chunk.timingData.length; i++) {
        TimingDatum timingDatum = chunk.timingData[i];
        uiRecords.add(UIRecord(
          time: timingDatum.time,
          place: startingPlace + i,
          textColor: Colors.black,
          type: RecordType.runnerTime,
        ));
        endingPlace++;
      }
    } else if (chunk.conflictRecord!.conflict!.type ==
        ConflictType.confirmRunner) {
      for (int i = 0; i < chunk.timingData.length; i++) {
        TimingDatum timingDatum = chunk.timingData[i];
        uiRecords.add(UIRecord(
          time: timingDatum.time,
          place: startingPlace + i,
          textColor: Colors.green,
          type: RecordType.runnerTime,
        ));
        endingPlace++;
      }
      uiRecords.add(UIRecord(
        time: chunk.conflictRecord!.time,
        place: null, // Don't assign a place to confirmation records
        textColor: Colors.green,
        type: RecordType.confirmRunner,
        conflictTime: chunk.conflictRecord!.time,
      ));
      // Don't increment endingPlace for confirmation records
    } else if (chunk.conflictRecord!.conflict!.type ==
        ConflictType.missingTime) {
      for (int i = 0; i < chunk.timingData.length; i++) {
        TimingDatum timingDatum = chunk.timingData[i];
        uiRecords.add(UIRecord(
          time: timingDatum.time,
          place: startingPlace + i,
          textColor: AppColors.redColor,
          type: RecordType.runnerTime,
        ));
        endingPlace++;
      }
      for (int i = 0; i < chunk.conflictRecord!.conflict!.offBy; i++) {
        uiRecords.add(UIRecord(
          time: 'TBD',
          place: endingPlace,
          textColor: AppColors.redColor,
          type: RecordType.missingTime,
          conflictTime: chunk.conflictRecord!.time,
        ));
        endingPlace++;
      }
    } else if (chunk.conflictRecord!.conflict!.type == ConflictType.extraTime) {
      final int extraTimesIndex =
          chunk.timingData.length - chunk.conflictRecord!.conflict!.offBy;
      for (int i = 0; i < extraTimesIndex; i++) {
        TimingDatum timingDatum = chunk.timingData[i];
        uiRecords.add(UIRecord(
          time: timingDatum.time,
          place: startingPlace + i,
          textColor: AppColors.redColor,
          type: RecordType.runnerTime,
        ));
        endingPlace++;
      }
      for (int i = extraTimesIndex; i < chunk.timingData.length; i++) {
        TimingDatum timingDatum = chunk.timingData[i];
        uiRecords.add(UIRecord(
          time: timingDatum.time,
          place: null,
          textColor: AppColors.redColor,
          type: RecordType.extraTime,
          conflictTime: chunk.conflictRecord!.time,
        ));
        // don't increment endingPlace
      }
    } else {
      // this should never happen
      throw Exception('Invalid conflict type');
    }

    return UIChunk(records: uiRecords, endingPlace: endingPlace);
  }

  void clearCache() {
    _cachedRecords.clear();
  }
}
