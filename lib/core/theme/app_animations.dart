import 'package:flutter/material.dart';

abstract final class AppAnimations {
  // Durations
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration reveal = Duration(milliseconds: 350);

  /// Input debounce delay (bib/name validation)
  static const Duration debounce = Duration(milliseconds: 500);

  /// Short toast / overlay notification duration
  static const Duration toastShort = Duration(seconds: 2);

  /// Long toast / overlay notification duration
  static const Duration toastLong = Duration(seconds: 3);

  // Curves
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve spring = Curves.easeInOutCubic;
}
