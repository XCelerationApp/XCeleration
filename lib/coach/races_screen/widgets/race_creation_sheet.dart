import 'package:flutter/material.dart';
import '../controller/races_controller.dart';
import 'action_button.dart';
import 'race_name_field.dart';

class RaceCreationSheet extends StatelessWidget {
  final bool isEditing;
  final int? raceId;
  final RacesController controller;

  const RaceCreationSheet({
    this.isEditing = false,
    this.raceId,
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaceNameField(controller: controller),
        const SizedBox(height: 12),
        ActionButton(controller: controller),
      ],
    );
  }
}
