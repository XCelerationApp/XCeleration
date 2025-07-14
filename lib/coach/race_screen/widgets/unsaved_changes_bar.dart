import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';

class UnsavedChangesBar extends StatelessWidget {
  final RaceController controller;

  const UnsavedChangesBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Only show the save bar during setup flow
    bool isSetupFlow = controller.race?.flowState == Race.FLOW_SETUP ||
        controller.race?.flowState == Race.FLOW_SETUP_COMPLETED;

    if (!controller.hasUnsavedChanges || !isSetupFlow) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          top: BorderSide(color: Colors.orange.shade200, width: 0.5),
          bottom: BorderSide(color: Colors.orange.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange.shade600,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You have made changes',
              style: AppTypography.bodyRegular.copyWith(
                color: Colors.orange.shade700,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => controller.revertAllChanges(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Revert',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => controller.saveAllChanges(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
