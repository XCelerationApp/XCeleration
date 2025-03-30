import 'package:flutter/material.dart';
// import 'action_button.dart';
import '../controller/share_race_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import 'format_selection_widget.dart';
// import '../../../../utils/enums.dart';

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
                controller.sendSms(context, controller.selectedFormat!);
              },
            ),
          ),

          // // Action Buttons
          // Container(
          //   margin: const EdgeInsets.only(top: 24),
          //   decoration: BoxDecoration(
          //     color: AppColors.backgroundColor,
          //     borderRadius: BorderRadius.circular(16),
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.stretch,
          //     children: [
          //       // Secondary Actions
          //       Row(
          //         children: [
          //           // Expanded(
          //           //   child: Padding(
          //           //     padding: const EdgeInsets.symmetric(horizontal: 8),
          //           //     child: ActionButton(
          //           //       icon: Icons.copy,
          //           //       label: controller.selectedFormat == ResultFormat.googleSheet 
          //           //         ? 'Copy Sheet Link'
          //           //         : 'Copy to Clipboard',
          //           //       onPressed: () => controller.copyToClipboard(context, controller.selectedFormat),
          //           //       isPrimary: false,
          //           //     ),
          //           //   ),
          //           // ),
          //           Expanded(
          //             child: Padding(
          //               padding: const EdgeInsets.symmetric(horizontal: 8),
          //               child: ActionButton(
          //                 icon: Icons.ios_share,
          //                 label: 'Share/Save',
          //                 onPressed: () => controller.sendSms(context, controller.selectedFormat),
          //                 isPrimary: false,
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 16),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}