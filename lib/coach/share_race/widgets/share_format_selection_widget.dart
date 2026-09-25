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
                  'Send to Spectators Nearby',
                  style: AppTypography.titleSemibold,
                ),
                const SizedBox(height: 8),
                Text(
                  'Parents and runners open Spectator on their phones and '
                  'tap Receive Race.',
                  style: AppTypography.bodyRegular
                      .copyWith(color: AppColors.mediumColor),
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
                    label: const Text('Send to Spectators'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Or Save a Copy',
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
