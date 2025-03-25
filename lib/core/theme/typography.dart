import 'package:flutter/material.dart';

/// A utility class that defines the typography scale for the app.
/// Following Material Design type scale with custom sizes.
class AppTypography {
  // Display styles
  static const String fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    height: 1.2, // 57.6px line height
    fontFamily: fontFamily,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.2, // 43.2px line height
    fontFamily: fontFamily,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    height: 1.2, // 36px line height
    fontFamily: fontFamily,
  );

  // Title styles
  static const TextStyle titleRegular = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.4, // 28px line height
    fontFamily: fontFamily,
  );

  static const TextStyle titleSemibold = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4, // 28px line height
    fontFamily: fontFamily,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3, // 31.2px line height
    fontFamily: fontFamily,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3, // 23.4px line height
    fontFamily: fontFamily,
  );

  // Header styles
  static const TextStyle headerRegular = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.33, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle headerSemibold = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.33, // 24px line height
    fontFamily: fontFamily,
  );

  // Body styles
  static const TextStyle bodyRegular = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle bodySemibold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.38, // 18px line height
    fontFamily: fontFamily,
  );

  // Small body styles
  static const TextStyle smallBodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43, // 20px line height
    fontFamily: fontFamily,
  );

  static const TextStyle smallBodySemibold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.43, // 20px line height
    fontFamily: fontFamily,
  );

  // Button text
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4, // 22.4px line height
    fontFamily: fontFamily,
  );
}
