import 'package:flutter/material.dart';

abstract final class AppShadows {
  /// Subtle card lift — most common.
  static const List<BoxShadow> low = [
    BoxShadow(
      color: Color(0x14000000), // black at 8%
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Glass surface depth.
  static const List<BoxShadow> glass = [
    BoxShadow(
      color: Color(0x1A000000), // black at 10%
      blurRadius: 40,
      offset: Offset(0, 20),
    ),
  ];

  /// Elevated action elements.
  static const List<BoxShadow> high = [
    BoxShadow(
      color: Color(0x29000000), // black at 16%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
