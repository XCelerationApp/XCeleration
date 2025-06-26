import 'package:flutter/material.dart';

/// A utility class that defines the typography scale for the app.
/// Following Material Design type scale with custom sizes.
class AppTypography {
  // Font family
  static const String fontFamily = 'Inter';

  // Font size constants - centralized for easy modification
  static const double displayLargeSize = 48;
  static const double displayMediumSize = 36;
  static const double displaySmallSize = 30;
  static const double titleLargeSize = 24;
  static const double titleSize = 20;
  static const double headerSize = 18;
  static const double bodySize = 16;
  static const double smallBodySize = 14;
  static const double captionSize = 13;
  static const double smallCaptionSize = 11;
  static const double extraSmallSize = 10;

  // Line height multipliers
  static const double displayLineHeight = 1.2;
  static const double titleLineHeight = 1.4;
  static const double headerLineHeight = 1.33;
  static const double bodyLineHeight = 1.5;
  static const double smallBodyLineHeight = 1.43;
  static const double buttonLineHeight = 1.4;

  // Display styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: displayLargeSize,
    fontWeight: FontWeight.w600,
    height: displayLineHeight, // 57.6px line height
    fontFamily: fontFamily,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: displayMediumSize,
    fontWeight: FontWeight.w600,
    height: displayLineHeight, // 43.2px line height
    fontFamily: fontFamily,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: displaySmallSize,
    fontWeight: FontWeight.w600,
    height: displayLineHeight, // 36px line height
    fontFamily: fontFamily,
  );

  // Title styles
  static const TextStyle titleRegular = TextStyle(
    fontSize: titleSize,
    fontWeight: FontWeight.w400,
    height: titleLineHeight, // 28px line height
    fontFamily: fontFamily,
  );

  static const TextStyle titleSemibold = TextStyle(
    fontSize: titleSize,
    fontWeight: FontWeight.w600,
    height: titleLineHeight, // 28px line height
    fontFamily: fontFamily,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: titleLargeSize,
    fontWeight: FontWeight.w600,
    height: 1.3, // 31.2px line height
    fontFamily: fontFamily,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: headerSize,
    fontWeight: FontWeight.w600,
    height: 1.3, // 23.4px line height
    fontFamily: fontFamily,
  );

  // Header styles
  static const TextStyle headerRegular = TextStyle(
    fontSize: headerSize,
    fontWeight: FontWeight.w400,
    height: headerLineHeight, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle headerSemibold = TextStyle(
    fontSize: headerSize,
    fontWeight: FontWeight.w600,
    height: headerLineHeight, // 24px line height
    fontFamily: fontFamily,
  );

  // Body styles
  static const TextStyle bodyRegular = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w400,
    height: bodyLineHeight, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle bodySemibold = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w600,
    height: bodyLineHeight, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w400,
    height: bodyLineHeight, // 24px line height
    fontFamily: fontFamily,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: captionSize,
    fontWeight: FontWeight.w400,
    height: 1.38, // 18px line height
    fontFamily: fontFamily,
  );

  // Small body styles
  static const TextStyle smallBodyRegular = TextStyle(
    fontSize: smallBodySize,
    fontWeight: FontWeight.w400,
    height: smallBodyLineHeight, // 20px line height
    fontFamily: fontFamily,
  );

  static const TextStyle smallBodySemibold = TextStyle(
    fontSize: smallBodySize,
    fontWeight: FontWeight.w600,
    height: smallBodyLineHeight, // 20px line height
    fontFamily: fontFamily,
  );

  // Caption styles for smaller text
  static const TextStyle caption = TextStyle(
    fontSize: captionSize,
    fontWeight: FontWeight.w400,
    height: smallBodyLineHeight,
    fontFamily: fontFamily,
  );

  static const TextStyle captionBold = TextStyle(
    fontSize: captionSize,
    fontWeight: FontWeight.w600,
    height: smallBodyLineHeight,
    fontFamily: fontFamily,
  );

  static const TextStyle smallCaption = TextStyle(
    fontSize: smallCaptionSize,
    fontWeight: FontWeight.w400,
    height: smallBodyLineHeight,
    fontFamily: fontFamily,
  );

  static const TextStyle extraSmall = TextStyle(
    fontSize: extraSmallSize,
    fontWeight: FontWeight.w400,
    height: smallBodyLineHeight,
    fontFamily: fontFamily,
  );

  // Button text
  static const TextStyle buttonText = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.w600,
    height: buttonLineHeight, // 22.4px line height
    fontFamily: fontFamily,
  );
}
