import 'dart:io';
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/race_screen_controller.dart';

class RaceLocationField extends StatelessWidget {
  final RaceController controller;
  final StateSetter setSheetState;
  final ValueChanged<String>? onChanged;

  const RaceLocationField({
    required this.controller,
    required this.setSheetState,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return buildInputRow(
      label: 'Location',
      inputWidget: Row(
        children: [
          Expanded(
            flex: 2,
            child: buildTextField(
              context: context,
              controller: controller.locationController,
              hint: (Platform.isIOS || Platform.isAndroid)
                  ? 'Other location'
                  : 'Enter race location',
              error: controller.locationError,
              setSheetState: setSheetState,
              onChanged: (value) {
                controller.validateLocation(
                    controller.locationController.text, setSheetState);
                if (onChanged != null) onChanged!(value);
              },
              keyboardType: TextInputType.text,
            ),
          ),
          if (controller.isLocationButtonVisible &&
              (Platform.isIOS || Platform.isAndroid)) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: IconButton(
                icon: const Icon(Icons.my_location,
                    color: AppColors.primaryColor),
                onPressed: () => controller.getCurrentLocation(context),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
