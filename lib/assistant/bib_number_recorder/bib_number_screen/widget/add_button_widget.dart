import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/tutorial_manager.dart';
import '../../../../../core/components/coach_mark.dart';

class AddButtonWidget extends StatelessWidget {
  final TutorialManager tutorialManager;
  final VoidCallback onTap;

  const AddButtonWidget({
    super.key,
    required this.tutorialManager,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: CoachMark(
          id: 'add_button_tutorial',
          tutorialManager: tutorialManager,
          config: const CoachMarkConfig(
            title: 'Add Runner',
            alignmentX: AlignmentX.center,
            alignmentY: AlignmentY.bottom,
            description: 'Click here to add a new runner',
            icon: Icons.add_circle_outline,
            type: CoachMarkType.targeted,
            backgroundColor: Color(0xFF1976D2),
            elevation: 12,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.add_circle_outline,
                size: 40,
                color: AppColors.primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
