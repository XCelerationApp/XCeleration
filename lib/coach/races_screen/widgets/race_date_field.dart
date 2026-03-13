import 'package:flutter/material.dart';
import 'package:xceleration/core/components/textfield_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/races_controller.dart';

class RaceDateField extends StatelessWidget {
  final RacesController controller;

  const RaceDateField({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => buildInputRow(
        label: 'Date',
        inputWidget: buildTextField(
          context: context,
          controller: controller.dateController,
          hint: 'YYYY-MM-DD',
          error: controller.dateError,
          suffixIcon: IconButton(
            icon:
                const Icon(Icons.calendar_today, color: AppColors.primaryColor),
            onPressed: () => controller.selectDate(context),
          ),
          onChanged: (_) =>
              controller.validateDate(controller.dateController.text),
        ),
      ),
    );
  }
}
