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
    // Use AnimatedBuilder to rebuild when controller changes
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display device connection widget
              deviceConnectionWidget(
                context,
                controller.devices,
                callback: () => controller.processReceivedData(context),
                inSheet: closeWhenDone,
              ),

              const SizedBox(height: 24),

              // Display conflicts or success message
              if (controller.resultsLoaded) ...[
                // Debug logging for conflict detection
                Builder(
                  builder: (context) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      debugPrint(
                          'UI - Results loaded: ${controller.resultsLoaded}');
                      debugPrint(
                          'UI - Bib conflicts: ${controller.hasBibConflicts}');
                      debugPrint(
                          'UI - Timing conflicts: ${controller.hasTimingConflicts}');
                    });
                    return const SizedBox.shrink();
                  },
                ),
                if (controller.hasBibConflicts || controller.hasTimingConflicts)
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
          ),
        );
      },
    );
  }
}
