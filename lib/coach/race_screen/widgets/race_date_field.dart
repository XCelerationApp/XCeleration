import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/textfield_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/race_screen_controller.dart';

class RaceDateField extends StatelessWidget {
  final RaceScreenController controller;
  final StateSetter setSheetState;
  final ValueChanged<String>? onChanged;

  const RaceDateField({
    required this.controller,
    required this.setSheetState,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return buildInputRow(
      label: 'Date',
      inputWidget: buildTextField(
        context: context,
        controller: controller.dateController,
        hint: 'YYYY-MM-DD',
        error: controller.dateError,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, color: AppColors.primaryColor),
          onPressed: () => controller.selectDate(context),
        ),
        setSheetState: setSheetState,
        onChanged: (value) {
          controller.validateDate(controller.dateController.text, setSheetState);
          if (onChanged != null) onChanged!(value);
        },
      ),
    );
  }
}
