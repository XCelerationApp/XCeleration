import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'package:xcelerate/coach/flows/PostRaceFlow/widgets/results_loader_widget.dart';
import 'package:xcelerate/utils/enums.dart';

/// A FlowStep implementation for the load results step in the post-race flow
class LoadResultsStep extends FlowStep {
  // Private fields to store state
  bool _resultsLoaded;
  bool _hasBibConflicts;
  bool _hasTimingConflicts;
  final Map<DeviceName, Map<String, dynamic>> _otherDevices;
  final Function() _reloadDevices;
  final Function(BuildContext context) _onResultsLoaded;
  final Function(BuildContext context) _showBibConflictsSheet;
  final Function(BuildContext context) _showTimingConflictsSheet;

  // Getters for the state
  bool get resultsLoaded => _resultsLoaded;
  bool get hasBibConflicts => _hasBibConflicts;
  bool get hasTimingConflicts => _hasTimingConflicts;
  
  // Setters for the state
  set resultsLoaded(bool value) {
    _resultsLoaded = value;
    notifyContentChanged();
  }
  
  set hasBibConflicts(bool value) {
    _hasBibConflicts = value;
    notifyContentChanged();
  }
  
  set hasTimingConflicts(bool value) {
    _hasTimingConflicts = value;
    notifyContentChanged();
  }

  /// Creates a new instance of LoadResultsStep
  LoadResultsStep({
    required Map<DeviceName, Map<String, dynamic>> otherDevices,
    required Function() reloadDevices,
    required Function(BuildContext context) onResultsLoaded,
    required Function(BuildContext context) showBibConflictsSheet,
    required Function(BuildContext context) showTimingConflictsSheet,
  }) :
    _resultsLoaded = false,
    _hasBibConflicts = false,
    _hasTimingConflicts = false,
    _otherDevices = otherDevices,
    _reloadDevices = reloadDevices,
    _onResultsLoaded = onResultsLoaded,
    _showBibConflictsSheet = showBibConflictsSheet,
    _showTimingConflictsSheet = showTimingConflictsSheet,
    super(
      title: 'Load Results',
      description: 'Load the results of the race from the assistant devices.',
      content: SingleChildScrollView(
        child: ResultsLoaderWidget(
          resultsLoaded: false,
          onResultsLoaded: onResultsLoaded,
          hasBibConflicts: false,
          hasTimingConflicts: false,
          otherDevices: otherDevices,
          onReloadPressed: () {},
          onBibConflictsPressed: (context) {},
          onTimingConflictsPressed: (context) {},
        ),
      ),
      canProceed: () async => true,
    );
  
  // Override to rebuild the content with current state
  @override
  Widget get content {
    return SingleChildScrollView(
      child: ResultsLoaderWidget(
        resultsLoaded: _resultsLoaded,
        onResultsLoaded: _onResultsLoaded,
        hasBibConflicts: _hasBibConflicts,
        hasTimingConflicts: _hasTimingConflicts,
        otherDevices: _otherDevices,
        onReloadPressed: _reloadDevices,
        onBibConflictsPressed: _showBibConflictsSheet,
        onTimingConflictsPressed: _showTimingConflictsSheet,
      ),
    );
  }
}