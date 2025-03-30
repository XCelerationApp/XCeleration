import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/textfield_utils.dart';
import '../controller/races_controller.dart';

class RaceDistanceField extends StatelessWidget {
  final RacesController controller;
  final StateSetter setSheetState;

  const RaceDistanceField(
      {required this.controller, required this.setSheetState, super.key});

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
              onChanged: (_) => controller.validateDistance(
                  controller.distanceController.text, setSheetState),
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
              onChanged: (value) => controller.unitController.text = value,
            ),
          ),
        ],
      ),
    );
  }
}
