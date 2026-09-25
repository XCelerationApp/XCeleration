import 'adjust_times.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'conflict_button.dart';
import 'success_message.dart';
import 'reload_button.dart';
import '../controller/load_results_controller.dart';
import '../dev/simulate_results_button.dart';

/// Widget that handles loading and displaying race results
class LoadResultsWidget extends StatelessWidget {
  /// Controller for loading and managing race results
  final LoadResultsController controller;

  /// Whether to immediately load test data (for development/testing)
  final bool testMode;

  /// Whether to close the flow when results are loaded
  final bool closeWhenDone;

  const LoadResultsWidget({
    super.key,
    required this.controller,
    this.closeWhenDone = false,
    this.testMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // The flow sheet leaves the sides to each page; these line up with the
    // page title.
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Read devices inside the builder so resetDevices() reassignments
              // are never stale.
              DeviceConnectionWidget(
                devices: controller.devices,
                callback: () => controller.processReceivedData(context),
                inSheet: closeWhenDone,
              ),

              // Test tools: in debug and profile builds, never in the store build.
              if (!kReleaseMode) ...[
                const SizedBox(height: 12),
                SimulateResultsButton(controller: controller),
              ],

              const SizedBox(height: 24),

              // Why the last load failed. Without this a failed load just
              // looked like nothing happened.
              if (controller.error case final error?) ...[
                Padding(
                  padding: EdgeInsets.zero,
                  child: Text(
                    error.userMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyRegular
                        .copyWith(color: AppColors.redColor),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Display conflicts or success message
                  if (controller.resultsLoaded) ...[
                    if (controller.hasBibConflicts ||
                        controller.hasTimingConflicts)
                      ConflictButton(
                        title: 'Some Results Need Checking',
                        description: 'Tap Next and the app walks you '
                            'through each one: bib numbers first, then '
                            'times.',
                        buttonText: 'Start',
                        onPressed: () {
                          debugPrint(
                              'Conflict button pressed - Bib conflicts: ${controller.hasBibConflicts}, Timing conflicts: ${controller.hasTimingConflicts}');
                          if (controller.hasBibConflicts) {
                            controller.showBibConflictsSheet(context);
                          } else {
                            controller.showTimingConflictsSheet(context);
                          }
                        },
                      )
                    else
                      const SuccessMessage(),
                    const SizedBox(height: 16),
                    AdjustTimesTile(
                      shift: controller.timeShift,
                      onShift: controller.shiftAllTimes,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Reload button
                  if (controller.resultsLoaded)
                    ReloadButton(onPressed: controller.resetDevices)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
