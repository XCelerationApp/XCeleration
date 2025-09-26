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
    return FutureBuilder<Race>(
      future: controller.masterRace.race,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final race = snapshot.data!;
        // Only show the save bar during setup flow
        bool isSetupFlow = race.flowState == Race.FLOW_SETUP ||
            race.flowState == Race.FLOW_SETUP_COMPLETED;

        if (!controller.hasUnsavedChanges || !isSetupFlow) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(
                top: BorderSide(color: Colors.orange.shade300, width: 0.5),
                bottom: BorderSide(color: Colors.orange.shade300, width: 0.5),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Revert',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => controller.saveAllChanges(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
