import 'package:flutter/material.dart';
import '../constants.dart';

Widget createSheetHandle() {
  return Container(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          width: 5.0,
          color: AppColors.backgroundColor,
          style: BorderStyle.solid,
        ),
        bottom: BorderSide(
          width: 5.0,
          color: AppColors.backgroundColor,
          style: BorderStyle.solid,
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: Container(
        height: 10.0,
        width: 50,
        color: AppColors.navBarColor,
      ),
    ),
  );
}