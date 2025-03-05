import 'package:flutter/material.dart';

/// A utility class that defines the typography scale for the app.
/// Following Material Design type scale with custom sizes.
class AppTypography {
  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    height: 1.2, // 57.6px line height
    fontFamily: 'monospace',
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.2, // 43.2px line height
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.2, // 36px line height
  );

  // Title styles
  static const TextStyle titleRegular = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4, // 28px line height
  );

  static const TextStyle titleSemibold = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4, // 28px line height
  );

  // Header styles
  static const TextStyle headerRegular = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.33, // 24px line height
  );

  static const TextStyle headerSemibold = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.33, // 24px line height
  );

  // Body styles
  static const TextStyle bodyRegular = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5, // 24px line height
  );

  static const TextStyle bodySemibold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5, // 24px line height
  );

  // Small body styles
  static const TextStyle smallBodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43, // 20px line height
  );

  static const TextStyle smallBodySemibold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43, // 20px line height
  );
}
