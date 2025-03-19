import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/device_connection_widget.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';
import 'conflict_button.dart';
import 'success_message.dart';
import 'reload_button.dart';

/// Widget that handles loading and displaying race results
class LoadResultsWidget extends StatelessWidget {
  /// Whether race results have been loaded
  final bool resultsLoaded;
  
  /// Whether there are bib conflicts in the loaded results
  final bool hasBibConflicts;
  
  /// Whether there are timing conflicts in the loaded results  
  final bool hasTimingConflicts;
  
  /// Map of connected devices and their data
  final DevicesManager devices;
  
  /// Function to call when reload button is pressed
  final VoidCallback onReloadPressed;
  
  /// Function to call when bib conflicts button is pressed
  final Function(BuildContext) onBibConflictsPressed;
  
  /// Function to call when timing conflicts button is pressed
  final Function(BuildContext) onTimingConflictsPressed;
  
  /// Function to call when results are loaded from devices
  final Function(BuildContext) onResultsLoaded;

  const LoadResultsWidget({
    super.key,
    required this.resultsLoaded,
    required this.hasBibConflicts,
    required this.hasTimingConflicts,
    required this.devices,
    required this.onReloadPressed,
    required this.onBibConflictsPressed,
    required this.onTimingConflictsPressed,
    required this.onResultsLoaded,
  });

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
              context,
              devices,
              callback: () => onResultsLoaded(context),
              inSheet: false
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
              const SuccessMessage(),
            ],
            const SizedBox(height: 16),
          ],

          if (resultsLoaded) 
            ReloadButton(onPressed: onReloadPressed)
          else 
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
