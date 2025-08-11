import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/utils/database_helper.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';

class AddRunnersToTeamSheet extends StatefulWidget {
  final MasterRace masterRace;
  final Team team;
  final Future<void> Function(List<int> selectedRunnerIds) onComplete;
  final VoidCallback? onRequestManualAdd;

  const AddRunnersToTeamSheet({
    super.key,
    required this.masterRace,
    required this.team,
    required this.onComplete,
    this.onRequestManualAdd,
  });

  @override
  State<AddRunnersToTeamSheet> createState() => _AddRunnersToTeamSheetState();
}

class _AddRunnersToTeamSheetState extends State<AddRunnersToTeamSheet> {
  final DatabaseHelper db = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Choose how you want to add runners to this team:',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onRequestManualAdd,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Runner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final tempController = RunnersManagementController(
                      masterRace: widget.masterRace);
                  await tempController.loadSpreadsheet(context, widget.team);
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Import From Spreadsheet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
