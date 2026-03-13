import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';
import '../controller/race_form_state.dart';

class RaceDistanceField extends StatelessWidget {
  final RaceController controller;
  final ValueChanged<String>? onChanged;

  const RaceDistanceField({
    required this.controller,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return buildInputRow(
      label: 'Distance',
      inputWidget: Row(
        children: [
          Expanded(
            flex: 2,
            child: buildTextField(
              context: context,
              controller: controller.form.distanceController,
              hint: '0.0',
              error: controller.form.errorFor(RaceField.distance),
              onChanged: (value) {
                controller
                    .validateDistance(controller.form.distanceController.text);
                // Only trigger autosave when we have valid input
                if (value.isNotEmpty &&
                    controller.form.errorFor(RaceField.distance) == null) {
                  if (onChanged != null) onChanged!(value);
                }
              },
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: AppDropdownField(
              controller: controller.form.unitController,
              hint: 'mi',
              items: ['mi', 'km'],
              onChanged: (value) {
                controller.form.unitController.text = value;
                if (onChanged != null) onChanged!(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
