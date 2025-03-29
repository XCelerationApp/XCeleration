import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/dialog_utils.dart';
import 'package:xcelerate/utils/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/race.dart';
import '../controller/races_controller.dart';

class ActionButton extends StatelessWidget {
  final RacesController controller;
  final bool isEditing;
  final int? raceId;
  
  const ActionButton({
    required this.controller, 
    this.isEditing = false, 
    this.raceId, 
    super.key
  });
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final error = controller.getFirstError();
        if (error != null) {
          DialogUtils.showErrorDialog(
            context,
            message: error,
          );
          return;
        }

        final race = Race(
          raceId: (isEditing && raceId != null ? raceId : 0)!,
          raceName: controller.nameController.text,
          location: controller.locationController.text,
          raceDate: DateTime.parse(controller.dateController.text),
          distance: double.parse(controller.distanceController.text),
          distanceUnit: controller.unitController.text,
          teams: controller.teamControllers
              .map((controller) => controller.text.trim())
              .where((text) => text.isNotEmpty)
              .toList(),
          teamColors: controller.teamColors,
          flowState: 'setup',
        );

        if (isEditing && raceId != null) {
          final flowState = (await DatabaseHelper.instance.getRaceById(raceId!))!.flowState;
          await DatabaseHelper.instance.updateRace(race.copyWith(flowState: flowState));
        } else {
          await DatabaseHelper.instance.insertRace(race);
        }
        await controller.loadRaces();

        Navigator.pop(context);
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppColors.primaryColor,
        fixedSize: const Size.fromHeight(64),
      ),
      child: Text(
        isEditing ? 'Save Changes' : 'Create Race',
        style: const TextStyle(fontSize: 24, color: Colors.white),
      ),
    );
  }
}
