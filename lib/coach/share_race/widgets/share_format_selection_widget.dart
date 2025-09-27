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
            'Wireless Share',
            style: AppTypography.titleRegular,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightColor, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share wirelessly (Nearby)',
                  style: AppTypography.titleSemibold,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Broadcast this finished race to nearby spectator devices.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      controller.shareWirelessly(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Share wirelessly'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Your Share Method',
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
              onShareSelected: (format) {
                Navigator.of(context).pop();
                controller.shareResults(context, format);
              },
            ),
          ),
        ],
      ),
    );
  }
}
