import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/device_connection_widget.dart';
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
            if (controller.hasBibConflicts)
              ConflictButton(
                title: 'Bib Numbers Not Found',
                description:
                    'Some runners have unfound bib numbers. Please resolve these conflicts before proceeding.',
                buttonText: 'Resolve Bib Numbers',
                onPressed: () => controller.showBibConflictsSheet(context),
              )
            else if (controller.hasTimingConflicts)
              ConflictButton(
                title: 'Timing Conflicts',
                description:
                    'There are conflicts in the race timing data. Please review and resolve these conflicts.',
                buttonText: 'Resolve Timing Conflicts',
                onPressed: () => controller.showTimingConflictsSheet(context),
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
  }
}
