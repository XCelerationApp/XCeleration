import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';

class RaceNameField extends StatelessWidget {
  final RaceScreenController controller;
  final StateSetter setSheetState;

  const RaceNameField(
      {required this.controller, required this.setSheetState, super.key});

  @override
  Widget build(BuildContext context) {
    return buildInputRow(
      label: 'Name',
      inputWidget: buildTextField(
        context: context,
        controller: controller.nameController,
        hint: 'Enter race name',
        error: controller.nameError,
        onChanged: (_) => controller.validateName(
            controller.nameController.text, setSheetState),
        setSheetState: setSheetState,
      ),
    );
  }
}
