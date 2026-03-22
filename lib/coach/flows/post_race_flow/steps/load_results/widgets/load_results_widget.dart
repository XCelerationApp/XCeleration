import 'package:flutter/material.dart';
import 'package:xceleration/core/components/device_connection_widget.dart';
import 'conflict_button.dart';
import 'success_message.dart';
import 'reload_button.dart';
import '../controller/load_results_controller.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // DeviceConnectionWidget does not depend on controller state changes;
          // keep it outside the AnimatedBuilder to avoid unnecessary rebuilds.
          DeviceConnectionWidget(
            devices: controller.devices,
            callback: () => controller.processReceivedData(context),
            inSheet: closeWhenDone,
          ),

          const SizedBox(height: 24),

          // Only the state-dependent section rebuilds on controller changes.
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Display conflicts or success message
                  if (controller.resultsLoaded) ...[
                    if (controller.hasBibConflicts ||
                        controller.hasTimingConflicts)
                      ConflictButton(
                        title: 'Race Conflicts',
                        description:
                            'Your race contains conflicts. Please resolve them before proceeding.',
                        buttonText: 'Resolve',
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
                  ],

                  // Reload button
                  if (controller.resultsLoaded)
                    ReloadButton(onPressed: controller.resetDevices)
                  else
                    const SizedBox.shrink(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
