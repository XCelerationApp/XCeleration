import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../controller/bib_number_controller.dart';
import 'dart:io';

class KeyboardAccessoryBar extends StatelessWidget {
  final VoidCallback onDone;
  final BibNumberController controller;

  const KeyboardAccessoryBar({
    super.key,
    required this.controller,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isRecording || !(Platform.isIOS || Platform.isAndroid) || !controller.isKeyboardVisible ||
        controller.bibRecords.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Color(0xFFD2D5DB), // iOS numeric keypad color
              border: Border(
                top: BorderSide(
                  color: Color(0xFFBBBBBB),
                  width: 0.5,
                ),
              ),
              borderRadius: BorderRadius.circular(4)
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
          )
        ),
        const SizedBox(height: 6)
      ]
    );
  }
}
