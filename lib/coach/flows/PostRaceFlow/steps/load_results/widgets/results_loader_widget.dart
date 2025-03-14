import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';
import 'package:xcelerate/core/components/device_connection_widget.dart';
import 'package:xcelerate/utils/enums.dart';
import 'conflict_button.dart';

class ResultsLoaderWidget extends StatelessWidget {
  final bool resultsLoaded;
  final Function(BuildContext context) onResultsLoaded;
  final bool hasBibConflicts;
  final bool hasTimingConflicts;
  final Map<DeviceName, Map<String, dynamic>> otherDevices;
  final VoidCallback onReloadPressed;
  final Function(BuildContext context) onBibConflictsPressed;
  final Function(BuildContext context) onTimingConflictsPressed;

  const ResultsLoaderWidget({
    Key? key,
    required this.resultsLoaded,
    required this.onResultsLoaded,
    required this.hasBibConflicts,
    required this.hasTimingConflicts,
    required this.otherDevices,
    required this.onReloadPressed,
    required this.onBibConflictsPressed,
    required this.onTimingConflictsPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: deviceConnectionWidget(
              DeviceName.coach,
              DeviceType.browserDevice,
              otherDevices,
              callback: () => onResultsLoaded(context),
            ),
          ),
          const SizedBox(height: 24),
          if (resultsLoaded) ...[
            if (hasBibConflicts) ...[
              ConflictButton(
                title: 'Bib Number Conflicts',
                description: 'Some runners have conflicting bib numbers. Please resolve these conflicts before proceeding.',
                onPressed: () => onBibConflictsPressed(context),
              ),
            ]
            else if (hasTimingConflicts) ...[
              ConflictButton(
                title: 'Timing Conflicts',
                description: 'There are conflicts in the race timing data. Please review and resolve these conflicts.',
                onPressed: () => onTimingConflictsPressed(context),
              ),
            ],
            if (!hasBibConflicts && !hasTimingConflicts) ...[
              Text(
                'Results Loaded Successfully',
                style: AppTypography.bodySemibold.copyWith(color: AppColors.primaryColor),
              ),
              const SizedBox(height: 8),
              Text(
                'You can proceed to review the results or load them again if needed.',
                style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
          ],

          resultsLoaded ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                minimumSize: const Size(240, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: onReloadPressed,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download_sharp, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Reload Results', style: AppTypography.bodySemibold.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ) : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
