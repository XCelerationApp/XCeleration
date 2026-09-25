import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../controller/bib_number_controller.dart';
import 'dart:io';

/// Sits right on top of the number pad while a bib is typed. Next Bib is
/// where the thumb already is, so a volunteer can type a bib and move on
/// without reaching up the screen; the number pad has no return key.
class KeyboardAccessoryBar extends StatelessWidget {
  final VoidCallback onDone;
  final BibNumberController controller;

  const KeyboardAccessoryBar({
    super.key,
    required this.controller,
    required this.onDone,
  });

  /// Whether the bar is showing in place of the big Add Bib button.
  static bool isShowing(BibNumberController controller, bool keyboardUp) =>
      keyboardUp &&
      !controller.raceStopped &&
      (Platform.isIOS || Platform.isAndroid) &&
      controller.bibRecords.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.keyboardVisibleNotifier,
      builder: (context, isKeyboardVisible, child) {
        if (!isShowing(controller, isKeyboardVisible)) {
          return const SizedBox.shrink();
        }
        return child!;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: RaceDayButton(
                key: const ValueKey('hide_keypad_button'),
                label: 'Hide',
                icon: Icons.keyboard_hide_outlined,
                color: AppColors.mediumColor,
                onPressed: onDone,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: RaceDayButton(
                key: const ValueKey('next_bib_button'),
                label: 'Next Bib',
                icon: Icons.arrow_downward_rounded,
                color: AppColors.primaryColor,
                filled: true,
                onPressed: controller.addBib,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
