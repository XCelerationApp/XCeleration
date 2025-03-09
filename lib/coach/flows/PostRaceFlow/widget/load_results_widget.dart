import 'package:flutter/material.dart';
import '../controller/post_race_flow_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../utils/enums.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../race_screen/widget/conflict_button.dart';
import '../../../race_screen/widget/bib_conflicts_sheet.dart';
import '../../../race_screen/widget/timing_conflicts_sheet.dart';

class LoadResultsWidget extends StatefulWidget {
  final PostRaceFlowController controller;
  final Map<DeviceName, Map<String, dynamic>> deviceConnections;
  final VoidCallback onReloadResults;
  
  const LoadResultsWidget({
    Key? key,
    required this.controller,
    required this.deviceConnections,
    required this.onReloadResults,
  }) : super(key: key);

  @override
  State<LoadResultsWidget> createState() => _LoadResultsWidgetState();
}

class _LoadResultsWidgetState extends State<LoadResultsWidget> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
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
                widget.deviceConnections,
              ),
            ),
            const SizedBox(height: 24),
            if (widget.controller.resultsLoaded) ...[
              if (widget.controller.hasBibConflicts) ...[
                _buildConflictButton(
                  'Bib Number Conflicts',
                  'Some runners have conflicting bib numbers. Please resolve these conflicts before proceeding.',
                  () => _showBibConflictsSheet(context),
                ),
              ]
              else if (widget.controller.hasTimingConflicts) ...[
                _buildConflictButton(
                  'Timing Conflicts',
                  'There are conflicts in the race timing data. Please review and resolve these conflicts.',
                  () => _showTimingConflictsSheet(context),
                ),
              ],
              if (!widget.controller.hasBibConflicts && !widget.controller.hasTimingConflicts) ...[
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

            widget.controller.resultsLoaded ? Container(
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_sharp, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Reload Results', style: AppTypography.bodySemibold.copyWith(color: Colors.white)),
                  ],
                ),
                onPressed: widget.onReloadResults
              ),
            ) : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConflictButton(String title, String description, VoidCallback onPressed) {
    return ConflictButton(
      title: title, 
      description: description, 
      onPressed: onPressed
    );
  }
  
  Future<void> _showBibConflictsSheet(BuildContext context) async {
    if (widget.controller.runnerRecords == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibConflictsSheet(
        runnerRecords: widget.controller.runnerRecords!,
      ),
    );
  }
  
  Future<void> _showTimingConflictsSheet(BuildContext context) async {
    if (widget.controller.timingData == null || widget.controller.runnerRecords == null) return;
    
    final conflictingRecords = getConflictingRecords(
      widget.controller.timingData!['records'], 
      widget.controller.timingData!['records'].length
    );
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimingConflictsSheet(
        conflictingRecords: conflictingRecords.cast<Map<String, dynamic>>(),
        timingData: widget.controller.timingData!,
        runnerRecords: widget.controller.runnerRecords!,
        raceId: widget.controller.raceId,
      ),
    );
  }
}

// Helper function to get conflicting records
List<Map<String, dynamic>> getConflictingRecords(List<dynamic> records, int numPlaces) {
  final conflicts = <Map<String, dynamic>>[];
  final bibTimes = <String, List<int>>{};
  
  // Find all bibs with multiple times
  for (var i = 0; i < numPlaces; i++) {
    final record = records[i];
    final bib = record['bib'].toString();
    if (!bibTimes.containsKey(bib)) {
      bibTimes[bib] = [];
    }
    bibTimes[bib]!.add(i);
  }
  
  // Create conflict records for bibs with multiple times
  for (final entry in bibTimes.entries) {
    if (entry.value.length > 1) {
      final times = entry.value.map((i) => records[i]['time']).toList();
      conflicts.add({
        'bib': entry.key,
        'times': times,
        'indices': entry.value,
      });
    }
  }
  
  return conflicts;
}
