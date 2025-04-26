import 'package:flutter/material.dart';
import '../controller/share_race_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import 'format_selection_widget.dart';

class ShareFormatSelectionWidget extends StatelessWidget {
  final ShareRaceController controller;
  const ShareFormatSelectionWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Format',
            style: AppTypography.titleRegular,
          ),
          const SizedBox(height: 16),
          // Format Selection
          Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.lightColor,
                width: 1,
              ),
            ),
            child: FormatSelectionWidget(
              selectedFormat: controller.selectedFormat,
              onFormatSelected: (format) {
                controller.selectedFormat = format;
                Navigator.of(context).pop();
                controller.sendSms(context, controller.selectedFormat!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
