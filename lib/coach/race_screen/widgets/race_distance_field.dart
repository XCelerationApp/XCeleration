import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';

class RaceDistanceField extends StatelessWidget {
  final RaceScreenController controller;
  final StateSetter setSheetState;
  final ValueChanged<String>? onChanged;

  const RaceDistanceField({
    required this.controller,
    required this.setSheetState,
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
              controller: controller.distanceController,
              hint: '0.0',
              error: controller.distanceError,
              setSheetState: setSheetState,
              onChanged: (value) {
                controller.validateDistance(controller.distanceController.text, setSheetState);
                // Only trigger autosave when we have valid input
                if (value.isNotEmpty && controller.distanceError == null) {
                  if (onChanged != null) onChanged!(value);
                }
              },
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: buildDropdown(
              controller: controller.unitController,
              hint: 'mi',
              error: null,
              setSheetState: setSheetState,
              items: ['mi', 'km'],
              onChanged: (value) {
                controller.unitController.text = value;
                if (onChanged != null) onChanged!(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
