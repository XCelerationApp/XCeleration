import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/dialog_utils.dart';
import 'package:xcelerate/utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../controller/races_controller.dart';
import '../../../core/components/button_components.dart';

class ActionButton extends StatelessWidget {
  final RacesController controller;
  final bool isEditing;
  final int? raceId;

  const ActionButton(
      {required this.controller,
      this.isEditing = false,
      this.raceId,
      super.key});

  @override
  Widget build(BuildContext context) {
    return FullWidthButton(
      text: isEditing ? 'Save Changes' : 'Create Race',
      fontSize: 24,
      borderRadius: 16,
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
        int newRaceId = race.raceId;
        if (isEditing && raceId != null) {
          final flowState =
              (await DatabaseHelper.instance.getRaceById(raceId!))!.flowState;
          await DatabaseHelper.instance
              .updateRace(race.copyWith(flowState: flowState));
        } else {
          newRaceId = await DatabaseHelper.instance.insertRace(race);
        }
        await controller.loadRaces();
        if (!context.mounted) return;
        Navigator.pop(context, newRaceId);
      },
    );
  }
}
