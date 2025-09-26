import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';

/// Represents a timing record optimized for UI display
class UIRecord {
  final String time;
  final int? place;
  final Color textColor;
  final RecordType type;
  final String? conflictTime;

  UIRecord({
    required this.time,
    this.place,
    required this.textColor,
    required this.type,
    this.conflictTime,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UIRecord &&
        other.time == time &&
        other.place == place &&
        other.textColor == textColor &&
        other.type == type &&
        other.conflictTime == conflictTime;
  }

  @override
  int get hashCode {
    return Object.hash(time, place, textColor, type, conflictTime);
  }

  @override
  String toString() {
    return 'UIRecord(time: $time, place: $place, type: $type, conflictTime: $conflictTime)';
  }
}

class UIChunk {
  final List<UIRecord> records;
  final int endingPlace;

  UIChunk({
    required this.records,
    required this.endingPlace,
  });
}
