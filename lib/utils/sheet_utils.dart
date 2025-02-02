import 'package:flutter/material.dart';
import 'app_colors.dart';

Widget createSheetHandle({double height = 10.0, double width = 50.0}) {
  return Container(
    alignment: Alignment.topCenter,
    // width: 50.0,
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
        height: height,
        width: width,
        color: AppColors.primaryColor,
      ),
    ),
  );
}

Widget createBackArrowBar(BuildContext context) {
  return Container(
    alignment: Alignment.topLeft,
    // width: 50.0,
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
    child: IconButton(
      icon: Icon(Icons.arrow_back),
      style: ButtonStyle(
        iconColor: WidgetStateProperty.all(AppColors.primaryColor),
      ),
      onPressed: () {
        Navigator.pop(context);
      },
    ),
  );
}