import 'package:flutter/material.dart';
import '../controller/races_controller.dart';
import 'action_button.dart';
// import 'competing_teams_field.dart';
// import 'race_date_field.dart';
// import 'race_location_field.dart';
import 'race_name_field.dart';
// import 'race_distance_field.dart';

class RaceCreationSheet extends StatelessWidget {
  final StateSetter setSheetState;
  final bool isEditing;
  final int? raceId;
  final RacesController controller;

  const RaceCreationSheet(
      {required this.setSheetState,
      this.isEditing = false,
      this.raceId,
      required this.controller,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaceNameField(controller: controller, setSheetState: setSheetState),
        // const SizedBox(height: 12),
        // CompetingTeamsField(
        //     controller: controller, setSheetState: setSheetState),
        // const SizedBox(height: 12),
        // RaceLocationField(
        //     controller: controller, setSheetState: setSheetState),
        // const SizedBox(height: 12),
        // RaceDateField(controller: controller, setSheetState: setSheetState),
        // const SizedBox(height: 12),
        // RaceDistanceField(
        //     controller: controller, setSheetState: setSheetState),
        const SizedBox(height: 12),
        ActionButton(
            controller: controller, isEditing: isEditing, raceId: raceId),
      ],
    );
  }
}
