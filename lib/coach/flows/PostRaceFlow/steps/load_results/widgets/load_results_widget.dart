import 'package:flutter/material.dart';
import 'package:xcelerate/core/components/device_connection_widget.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';
import 'conflict_button.dart';
import 'success_message.dart';
import 'reload_button.dart';

/// Widget that handles loading and displaying race results
class LoadResultsWidget extends StatefulWidget {
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
  
  /// Whether to immediately load test data (for development/testing)
  final bool testMode;

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
    this.testMode = false,
  });

  @override
  State<LoadResultsWidget> createState() => _LoadResultsWidgetState();
}

class _LoadResultsWidgetState extends State<LoadResultsWidget> {
  @override
  void initState() {
    super.initState();
    
    // Automatically load test data if in test mode
    if (widget.testMode && !widget.resultsLoaded) {
      // Use a small delay to ensure the widget is fully built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('Loading test data...');
          widget.onResultsLoaded(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.testMode)
            Center(
              child: deviceConnectionWidget(
                context,
                widget.devices,
                callback: () => widget.onResultsLoaded(context),
              ),
            )
          else if (!widget.resultsLoaded)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading test data...', 
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (widget.resultsLoaded) ...[
            if (widget.hasBibConflicts) ...[
              ConflictButton(
                title: 'Bib Number Conflicts',
                description: 'Some runners have conflicting bib numbers. Please resolve these conflicts before proceeding.',
                onPressed: () => widget.onBibConflictsPressed(context),
              ),
            ]
            else if (widget.hasTimingConflicts) ...[
              ConflictButton(
                title: 'Timing Conflicts',
                description: 'There are conflicts in the race timing data. Please review and resolve these conflicts.',
                onPressed: () => widget.onTimingConflictsPressed(context),
              ),
            ],
            if (!widget.hasBibConflicts && !widget.hasTimingConflicts) ...[
              const SuccessMessage(),
            ],
            const SizedBox(height: 16),
          ],

          if (widget.resultsLoaded) 
            ReloadButton(onPressed: widget.onReloadPressed)
          else 
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
