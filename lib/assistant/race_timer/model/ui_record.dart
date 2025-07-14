import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';

/// Represents a timing record optimized for UI display
class UIRecord {
  final String time;
  final int? place;
  final Color textColor;
  final RecordType type;
  final Conflict? conflict;
  final int index;
  final bool isConfirmed;

  UIRecord({
    required this.time,
    this.place,
    required this.textColor,
    required this.type,
    this.conflict,
    required this.index,
    required this.isConfirmed,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UIRecord &&
        other.time == time &&
        other.place == place &&
        other.textColor == textColor &&
        other.type == type &&
        other.conflict == conflict &&
        other.index == index &&
        other.isConfirmed == isConfirmed;
  }

  @override
  int get hashCode {
    return Object.hash(
        time, place, textColor, type, conflict, index, isConfirmed);
  }

  @override
  String toString() {
    return 'UIRecord(time: $time, place: $place, type: $type, index: $index, isConfirmed: $isConfirmed)';
  }
}

/// Cache for conversion performance optimization
class ConversionCache {
  final List<TimingDatum> lastRecords;
  final List<UIRecord> lastUIRecords;
  final DateTime lastConversion;

  ConversionCache({
    required this.lastRecords,
    required this.lastUIRecords,
    required this.lastConversion,
  });
}
