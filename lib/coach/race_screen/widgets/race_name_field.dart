import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';

class RaceNameField extends StatelessWidget {
  final RaceScreenController controller;
  final StateSetter setSheetState;
  final ValueChanged<String>? onChanged;

  const RaceNameField({
    required this.controller,
    required this.setSheetState,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return buildInputRow(
      label: 'Name',
      inputWidget: buildTextField(
        context: context,
        controller: controller.nameController,
        hint: 'Enter race name',
        error: controller.nameError,
        onChanged: (value) {
          controller.validateName(controller.nameController.text, setSheetState);
          if (onChanged != null) onChanged!(value);
        },
        setSheetState: setSheetState,
      ),
    );
  }
}
