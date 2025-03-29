import 'package:flutter/material.dart';
// import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';

class KeyboardAccessoryBar extends StatelessWidget {
  final VoidCallback onDone;

  const KeyboardAccessoryBar({
    super.key,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFD2D5DB), // iOS numeric keypad color
        border: Border(
          top: BorderSide(
            color: Color(0xFFBBBBBB),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                overlayColor: const Color.fromARGB(255, 78, 78, 80),
              ),
              child: Text(
                'Done',
                style: AppTypography.bodyRegular.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
