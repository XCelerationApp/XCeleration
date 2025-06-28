import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../controller/merge_conflicts_controller.dart';
import '../services/simple_conflict_resolver.dart';
import '../../../core/utils/enums.dart';

/// Simple, intuitive UI for conflict resolution
/// Shows conflicts in a clear list format with straightforward resolution options
class SimpleConflictWidget extends StatefulWidget {
  final MergeConflictsController controller;

  const SimpleConflictWidget({
    super.key,
    required this.controller,
  });

  @override
  State<SimpleConflictWidget> createState() => _SimpleConflictWidgetState();
}

class _SimpleConflictWidgetState extends State<SimpleConflictWidget> {
  final Map<int, List<TextEditingController>> _timeControllers = {};
  final Map<int, Set<String>> _selectedTimesToRemove = {};

  @override
  void dispose() {
    // Clean up controllers
    for (final controllers in _timeControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final conflicts = widget.controller.getConflictsSimple();

        if (conflicts.isEmpty) {
          return _buildNoConflictsView();
        }

        return Column(
          children: [
            _buildModeToggle(),
            const SizedBox(height: 16),
            _buildConflictsList(conflicts),
            const SizedBox(height: 16),
            _buildSaveButton(),
          ],
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.science, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'Simple Mode Active',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: widget.controller.toggleMode,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch to Complex Mode'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConflictsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No Conflicts Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'All timing records are properly resolved',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 24),
          _buildModeToggle(),
        ],
      ),
    );
  }

  Widget _buildConflictsList(List<ConflictInfo> conflicts) {
    return Expanded(
      child: ListView.builder(
        itemCount: conflicts.length,
        itemBuilder: (context, index) {
          final conflict = conflicts[index];
          return _buildConflictCard(conflict, index);
        },
      ),
    );
  }

  Widget _buildConflictCard(ConflictInfo conflict, int conflictIndex) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConflictHeader(conflict),
            const SizedBox(height: 16),
            _buildConflictResolution(conflict, conflictIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictHeader(ConflictInfo conflict) {
    final isExtraTime = conflict.type == RecordType.extraTime;
    final color = isExtraTime ? Colors.orange : Colors.blue;
    final icon = isExtraTime ? Icons.remove_circle : Icons.add_circle;

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Place ${conflict.place}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                conflict.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: ColorUtils.withOpacity(color, 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.withOpacity(color, 0.3)),
          ),
          child: Text(
            conflict.elapsedTime,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConflictResolution(ConflictInfo conflict, int conflictIndex) {
    switch (conflict.type) {
      case RecordType.missingTime:
        return _buildMissingTimeResolution(conflict, conflictIndex);
      case RecordType.extraTime:
        return _buildExtraTimeResolution(conflict, conflictIndex);
      default:
        return _buildGenericResolution(conflict);
    }
  }

  Widget _buildMissingTimeResolution(ConflictInfo conflict, int conflictIndex) {
    // Initialize controllers if needed
    if (!_timeControllers.containsKey(conflictIndex)) {
      _timeControllers[conflictIndex] = [TextEditingController()];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter missing time:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _timeControllers[conflictIndex]![0],
                decoration: const InputDecoration(
                  hintText: 'e.g., 1:23.45',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => _resolveMissingTime(conflict, conflictIndex),
              icon: const Icon(Icons.add),
              label: const Text('Add Time'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExtraTimeResolution(ConflictInfo conflict, int conflictIndex) {
    // Get all available times for this conflict area
    final availableTimes = _getAvailableTimesForConflict(conflict);

    Logger.d(
        'DEBUG: Building extra time resolution for conflict at place ${conflict.place}');
    Logger.d('DEBUG: Available times count: ${availableTimes.length}');
    Logger.d('DEBUG: Available times: $availableTimes');

    // Initialize selected times if needed
    if (!_selectedTimesToRemove.containsKey(conflictIndex)) {
      _selectedTimesToRemove[conflictIndex] = <String>{};
    }

    if (availableTimes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No times available to remove:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Debug: Conflict at place ${conflict.place}, but no nearby times found.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select times to remove:',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...availableTimes.map((time) => CheckboxListTile(
              title: Text(time),
              value: _selectedTimesToRemove[conflictIndex]!.contains(time),
              onChanged: (selected) {
                setState(() {
                  if (selected == true) {
                    _selectedTimesToRemove[conflictIndex]!.add(time);
                  } else {
                    _selectedTimesToRemove[conflictIndex]!.remove(time);
                  }
                });
              },
              dense: true,
            )),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _selectedTimesToRemove[conflictIndex]!.isNotEmpty
              ? () => _resolveExtraTime(conflict, conflictIndex)
              : null,
          icon: const Icon(Icons.remove),
          label: Text(
              'Remove ${_selectedTimesToRemove[conflictIndex]!.length} Time(s)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGenericResolution(ConflictInfo conflict) {
    return Text(
      'Conflict type ${conflict.type} - Manual resolution required',
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildSaveButton() {
    final hasConflicts = widget.controller.hasUnresolvedConflictsSimple();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed:
              hasConflicts ? null : () => widget.controller.saveResults(),
          icon: Icon(hasConflicts ? Icons.warning : Icons.save),
          label: Text(
              hasConflicts ? 'Resolve All Conflicts First' : 'Save Results'),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasConflicts ? Colors.grey : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  List<String> _getAvailableTimesForConflict(ConflictInfo conflict) {
    // For extra time conflicts, we need to find all times that could be removed
    // This includes times around the conflict place and any unassigned times
    final allRecords = widget.controller.timingData.records;

    // Get all runner time records with valid times
    final runnerTimeRecords = allRecords
        .where((record) =>
            record.type == RecordType.runnerTime &&
            record.elapsedTime.isNotEmpty &&
            record.elapsedTime != 'TBD')
        .toList();

    // For extra time conflicts, include times from nearby places
    final nearbyTimes = runnerTimeRecords
        .where((record) =>
            record.place != null &&
            (record.place! - conflict.place).abs() <= 3) // Increased range
        .map((record) => record.elapsedTime)
        .toSet()
        .toList();

    // Also include any times that might be duplicates or unassigned
    final allTimes =
        runnerTimeRecords.map((record) => record.elapsedTime).toSet().toList();

    // Combine both approaches - prefer nearby times but include all if needed
    final availableTimes = nearbyTimes.isNotEmpty ? nearbyTimes : allTimes;

    // Debug logging
    Logger.d('DEBUG: Conflict at place ${conflict.place}');
    Logger.d(
        'DEBUG: All records: ${allRecords.map((r) => 'Place: ${r.place}, Time: ${r.elapsedTime}, Type: ${r.type}').toList()}');
    Logger.d(
        'DEBUG: Runner time records: ${runnerTimeRecords.map((r) => 'Place: ${r.place}, Time: ${r.elapsedTime}').toList()}');
    Logger.d('DEBUG: Nearby times: $nearbyTimes');
    Logger.d('DEBUG: All times: $allTimes');
    Logger.d('DEBUG: Final available times: $availableTimes');

    return availableTimes;
  }

  void _resolveMissingTime(ConflictInfo conflict, int conflictIndex) {
    final timeText = _timeControllers[conflictIndex]![0].text.trim();

    if (timeText.isEmpty) {
      _showError('Please enter a time');
      return;
    }

    widget.controller.handleMissingTimesSimple(
      userTimes: [timeText],
      conflictPlace: conflict.place,
    );

    // Clear the input
    _timeControllers[conflictIndex]![0].clear();
  }

  void _resolveExtraTime(ConflictInfo conflict, int conflictIndex) {
    final timesToRemove = _selectedTimesToRemove[conflictIndex]!.toList();

    if (timesToRemove.isEmpty) {
      _showError('Please select times to remove');
      return;
    }

    widget.controller.handleExtraTimesSimple(
      timesToRemove: timesToRemove,
      conflictPlace: conflict.place,
    );

    // Clear selections
    _selectedTimesToRemove[conflictIndex]!.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
