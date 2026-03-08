import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/races_controller.dart';

class RaceNameField extends StatelessWidget {
  final RacesController controller;

  const RaceNameField({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => buildInputRow(
        label: 'Name',
        inputWidget: buildTextField(
          context: context,
          controller: controller.nameController,
          hint: 'Enter race name',
          error: controller.nameError,
          onChanged: (_) =>
              controller.validateName(controller.nameController.text),
        ),
      ),
    );
  }
}
