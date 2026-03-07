import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';
import '../controller/race_form_state.dart';

class RaceNameField extends StatelessWidget {
  final RaceController controller;
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
        controller: controller.form.nameController,
        hint: 'Enter race name',
        error: controller.form.errorFor(RaceField.name),
        onChanged: (value) {
          controller.validateName(controller.form.nameController.text);
          if (onChanged != null) onChanged!(value);
        },
        setSheetState: setSheetState,
      ),
    );
  }
}
