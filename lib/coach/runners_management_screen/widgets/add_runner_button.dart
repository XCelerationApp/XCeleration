import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dropup_button.dart';
import '../controller/runners_management_controller.dart';
import 'package:xceleration/shared/models/database/team.dart';

class AddRunnerButton extends StatelessWidget {
  final Team team;
  final RunnersManagementController controller;
  final VoidCallback? onRunnerAdded;

  const AddRunnerButton({
    super.key,
    required this.team,
    required this.controller,
    this.onRunnerAdded,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.isViewMode) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropupButton<String>(
        onSelected: (action) {
          if (action == 'single') {
            controller.showAddRunnerToTeam(context, team);
          } else if (action == 'spreadsheet') {
            controller.showImportRunnersToTeam(context, team);
          }
        },
        verticalOffset: 0,
        elevation: 4,
        menuShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        menuColor: Colors.white,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryColor,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: AppColors.primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        items: [
          PopupMenuItem<String>(
            value: 'single',
            child: Row(
              children: [
                Icon(Icons.person_add, color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 12),
                const Text('Add Single Runner'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'spreadsheet',
            child: Row(
              children: [
                Icon(Icons.upload_file,
                    color: AppColors.primaryColor, size: 20),
                const SizedBox(width: 12),
                const Text('Import from Spreadsheet'),
              ],
            ),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: AppColors.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Add Runner',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
