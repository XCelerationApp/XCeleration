import 'package:flutter/material.dart';
import 'package:xcelerate/coach/flows/model/flow_model.dart';
import 'widgets/load_results_widget.dart';
import 'package:xcelerate/core/services/device_connection_service.dart';

/// A FlowStep implementation for the load results step in the post-race flow
class LoadResultsStep extends FlowStep {
  // Private fields to store state
  bool _resultsLoaded;
  bool _hasBibConflicts;
  bool _hasTimingConflicts;
  final DevicesManager _devices;
  final Function() _reloadDevices;
  final Function(BuildContext context) _onResultsLoaded;
  final Function(BuildContext context) _showBibConflictsSheet;
  final Function(BuildContext context) _showTimingConflictsSheet;
  final bool _testMode;

  // Getters for the state
  bool get resultsLoaded => _resultsLoaded;
  set resultsLoaded(bool value) {
    if (_resultsLoaded != value) {
      _resultsLoaded = value;
      notifyContentChanged();
    }
  }
  
  bool get hasBibConflicts => _hasBibConflicts;
  set hasBibConflicts(bool value) {
    if (_hasBibConflicts != value) {
      _hasBibConflicts = value;
      notifyContentChanged();
    }
  }
  
  bool get hasTimingConflicts => _hasTimingConflicts;
  set hasTimingConflicts(bool value) {
    if (_hasTimingConflicts != value) {
      _hasTimingConflicts = value;
      notifyContentChanged();
    }
  }

  /// Creates a new instance of LoadResultsStep
  LoadResultsStep({
    required DevicesManager devices,
    required Function() reloadDevices,
    required Function(BuildContext context) onResultsLoaded,
    required Function(BuildContext context) showBibConflictsSheet,
    required Function(BuildContext context) showTimingConflictsSheet,
    bool testMode = false,
  }) :
    _resultsLoaded = false,
    _hasBibConflicts = false,
    _hasTimingConflicts = false,
    _devices = devices,
    _reloadDevices = reloadDevices,
    _onResultsLoaded = onResultsLoaded,
    _showBibConflictsSheet = showBibConflictsSheet,
    _showTimingConflictsSheet = showTimingConflictsSheet,
    _testMode = testMode,
    super(
      title: 'Load Results',
      description: 'Load the results of the race from the assistant devices.',
      content: SingleChildScrollView(
        child: LoadResultsWidget(
          resultsLoaded: false,
          onResultsLoaded: onResultsLoaded,
          hasBibConflicts: false,
          hasTimingConflicts: false,
          devices: devices,
          onReloadPressed: () {},
          onBibConflictsPressed: (context) {},
          onTimingConflictsPressed: (context) {},
          testMode: testMode,
        ),
      ),
      canProceed: () => true,
    );
  
  // Override to rebuild the content with current state
  @override
  Widget get content {
    return SingleChildScrollView(
      child: LoadResultsWidget(
        resultsLoaded: _resultsLoaded,
        onResultsLoaded: _onResultsLoaded,
        hasBibConflicts: _hasBibConflicts,
        hasTimingConflicts: _hasTimingConflicts,
        devices: _devices,
        onReloadPressed: _reloadDevices,
        onBibConflictsPressed: _showBibConflictsSheet,
        onTimingConflictsPressed: _showTimingConflictsSheet,
        testMode: _testMode,
      ),
    );
  }
}