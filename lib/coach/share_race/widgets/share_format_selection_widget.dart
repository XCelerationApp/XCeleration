import 'package:flutter/material.dart';
import 'action_button.dart';
import '../controller/share_race_controller.dart';
import '../../../../utils/enums.dart';



class ShareFormatSelectionWidget extends StatelessWidget {
  final ShareRaceController controller;
  const ShareFormatSelectionWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Action Buttons
        ActionButton(
          icon: controller.selectedFormat == ResultFormat.googleSheet
              ? Icons.cloud_upload
              : Icons.save,
          label: controller.selectedFormat == ResultFormat.googleSheet
              ? 'Export to Google Sheets'
              : 'Save Locally',
          onPressed: () => controller.selectedFormat == ResultFormat.googleSheet
              ? controller.exportToGoogleSheets(context)
              : controller.saveLocally(context, controller.selectedFormat),
        ),
        const SizedBox(height: 12),
        ActionButton(
          icon: Icons.copy,
          label: controller.selectedFormat == ResultFormat.googleSheet
              ? 'Copy Sheet Link'
              : 'Copy to Clipboard',
          onPressed: controller.selectedFormat == ResultFormat.pdf
              ? null
              : () => controller.copyToClipboard(context, controller.selectedFormat),
        ),
        const SizedBox(height: 12),
        ActionButton(
          icon: Icons.email,
          label: 'Send via Email',
          onPressed: () => controller.sendEmail(context, controller.selectedFormat),
        ),
        const SizedBox(height: 12),
        ActionButton(
          icon: Icons.sms,
          label: 'Send via SMS',
          onPressed: () => controller.sendSms(context, controller.selectedFormat),
        ),
      ],
    );
  }
}