import 'package:flutter/material.dart';
// import 'package:xceleration/core/utils/color_utils.dart';

/// Utility class for color-related operations
class ColorUtils {
  /// Creates a color with RGBA values to replace the deprecated withOpacity method
  /// 
  /// Example usage: 
  /// ```dart
  /// // Instead of: Colors.black.withOpacity(0.5)
  /// ColorUtils.withOpacity(Colors.black, 0.5)
  /// ```
  static Color withOpacity(Color color, double opacity) {
    return Color.fromRGBO(
      color.r.toInt(), 
      color.g.toInt(), 
      color.b.toInt(), 
      opacity
    );
  }
}
