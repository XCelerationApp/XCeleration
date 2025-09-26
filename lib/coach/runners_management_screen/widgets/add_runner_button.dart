import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          onPressed: () => controller.showAddRunnersToTeamSheet(context, team),
          icon: const Icon(Icons.add),
          color: AppColors.primaryColor,
          tooltip: 'Add runners',
        ),
      ),
    );
  }
}
