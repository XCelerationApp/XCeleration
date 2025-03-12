import 'package:xcelerate/coach/race_screen/widgets/bib_conflicts_sheet.dart';
import 'package:xcelerate/coach/race_screen/widgets/timing_conflicts_sheet.dart';
import '../../controller/flow_controller.dart';
import '../../model/flow_model.dart';
import 'package:flutter/material.dart';
import '../../../../utils/enums.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../../utils/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../race_screen/widgets/conflict_button.dart';
import '../../../../utils/runner_time_functions.dart';
import '../../../../utils/encode_utils.dart';

class PostRaceController {
  final int raceId;
  PostRaceController({required this.raceId}) {
    loadResults();
  }

  Future<void> loadResults() async {
    final savedResults = await DatabaseHelper.instance.getRaceResultsData(raceId);
    if (savedResults != null) {
      runnerRecords = savedResults['runnerRecords'];
      timingData = savedResults['timingData'];
      resultsLoaded = true;
      
      // Check for conflicts in the loaded data
      hasBibConflicts = runnerRecords != null && containsBibConflicts(runnerRecords!);
      hasTimingConflicts = timingData != null && containsTimingConflicts(timingData!);
    }
  }
  /// Save race results to the database
  Future<void> saveRaceResults() async {
    if (runnerRecords != null && timingData != null) {
      await DatabaseHelper.instance.saveRaceResults(
        raceId,
        {
          'runnerRecords': runnerRecords,
          'timingData': timingData,
        },
      );
    }
  }

  /// Process received data from other devices
  Future<void> processReceivedData(String? bibRecordsData, String? finishTimesData, BuildContext context) async {
    if (bibRecordsData == null || finishTimesData == null) {
      return;
    }
    
    var processedRunnerRecords = await processEncodedBibRecordsData(bibRecordsData, context, raceId);
    final processedTimingData = await processEncodedTimingData(finishTimesData, context);
    
    if (processedRunnerRecords.isNotEmpty && processedTimingData != null) {
      processedTimingData['records'] = await syncBibData(
        processedRunnerRecords.length, 
        processedTimingData['records'], 
        processedTimingData['endTime'], 
        context
      );
      
      runnerRecords = processedRunnerRecords;
      timingData = processedTimingData;
      resultsLoaded = true;
      
      await saveRaceResults();
    }
  }
  Map<DeviceName, Map<String, dynamic>> otherDevices = DeviceConnectionService.createOtherDeviceList(
    DeviceName.coach,
    DeviceType.browserDevice,
  );

  bool hasBibConflicts = false;
  bool hasTimingConflicts = false;
  bool resultsLoaded = false;
  List<Map<String, dynamic>>? runnerRecords;
  Map<String, dynamic>? timingData;

  
  Future<bool> showPostRaceFlow(BuildContext context, bool showProgressIndicator) {
    return showFlow(
      context: context,
      showProgressIndicator: showProgressIndicator,
      steps: _getSteps(context),
    );
  }

  Widget _buildConflictButton(String title, String description, VoidCallback onPressed) {
    return ConflictButton(
      title: title,
      description: description,
      onPressed: onPressed,
    );
  }

  bool containsBibConflicts(List<dynamic> records) {
    return records.any((record) => record['error'] != null);
  }

  bool containsTimingConflicts(Map<String, dynamic> data) {
    return getConflictingRecords(data['records'], data['records'].length).isNotEmpty;
  }

  Future<void> showBibConflictsSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibConflictsSheet(runnerRecords: runnerRecords!),
    );
  }

  Future<void> showTimingConflictsSheet(BuildContext context) async {
    final conflictingRecords = getConflictingRecords(timingData!['records'], timingData!['records'].length);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimingConflictsSheet(
        conflictingRecords: conflictingRecords.cast<Map<String, dynamic>>(),
        timingData: timingData!,
        runnerRecords: runnerRecords!,
        raceId: raceId,
      ),
    );
  }
  List<FlowStep> _getSteps(BuildContext context) {
    return [
      FlowStep(
        title: 'Load Results',
        description: 'Load the results of the race from the assistant devices.',
        content: SingleChildScrollView(
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
                    otherDevices,
                    // callback: () async {
                    //   final encodedBibRecords = otherDevices[DeviceName.bibRecorder]?['data'] as String?;
                    //   final encodedFinishTimes = otherDevices[DeviceName.raceTimer]?['data'] as String?;

                    //   if (encodedBibRecords == null || encodedFinishTimes == null) {
                    //     return;
                    //   }
                      
                    //   var runnerRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
                    //   final timingData = await processEncodedTimingData(encodedFinishTimes, context);
                      
                    //   if (runnerRecords.isNotEmpty && timingData != null) {
                    //     timingData['records'] = await syncBibData(runnerRecords.length, timingData['records'], timingData['endTime'], context);
                    //     setState(() {
                    //       _runnerRecords = runnerRecords;
                    //       _timingData = timingData;
                    //       _resultsLoaded = true;
                    //       _hasBibConflicts = _containsBibConflicts(runnerRecords);
                    //       _hasTimingConflicts = _containsTimingConflicts(timingData);
                    //     });
                        
                    //     await _saveRaceResults();
                    //   }
                    // }
                  ),
                ),
                const SizedBox(height: 24),
                if (resultsLoaded) ...[
                  if (hasBibConflicts) ...[
                    _buildConflictButton(
                      'Bib Number Conflicts',
                      'Some runners have conflicting bib numbers. Please resolve these conflicts before proceeding.',
                      () => showBibConflictsSheet(context),
                    ),
                  ]
                  else if (hasTimingConflicts) ...[
                    _buildConflictButton(
                      'Timing Conflicts',
                      'There are conflicts in the race timing data. Please review and resolve these conflicts.',
                      () => showTimingConflictsSheet(context),
                    ),
                  ],
                  if (!hasBibConflicts && !hasTimingConflicts) ...[
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

                resultsLoaded ? Container(
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
                        Icon(Icons.download_sharp, color: Colors.white),
                        const SizedBox(width: 12),
                        Text('Reload Results', style: AppTypography.bodySemibold.copyWith(color: Colors.white)),
                      ],
                    ),
                    onPressed: () async {
                      resultsLoaded = false;
                      hasBibConflicts = false;
                      hasTimingConflicts = false;
                      otherDevices = DeviceConnectionService.createOtherDeviceList(
                        DeviceName.coach,
                        DeviceType.browserDevice,
                      );
                    }
                  ),
                ) : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Review Results',
        description: 'Review and verify the race results before saving them.',
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fact_check_outlined, size: 80, color: AppColors.primaryColor),
              const SizedBox(height: 24),
              Text(
                'Review Race Results',
                style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Make sure all times and placements are correct.',
                style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Placeholder for results table
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text('Place', 
                            style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Runner', 
                            style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Time', 
                            style: AppTypography.bodySemibold.copyWith(color: AppColors.darkColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Placeholder rows
                    for (var i = 1; i <= 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(i.toString()),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Runner $i'),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${(i * 15.5).toStringAsFixed(2)}s'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Save Results',
        description: 'Save the final race results to complete the race.',
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.save_outlined, size: 80, color: AppColors.primaryColor),
              const SizedBox(height: 24),
              Text(
                'Save Race Results',
                style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Click Next to save the results and complete the race.',
                style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        canProceed: () async => true,
      ),
    ];

    // await waitForDataTransferCompletion(otherDevices);
    // final encodedBibRecords = otherDevices[DeviceName.bibRecorder]?['data'] as String?;
    // final encodedFinishTimes = otherDevices[DeviceName.raceTimer]?['data'] as String?;
    
    // var runnerRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
    // final timingData = await processEncodedTimingData(encodedFinishTimes, context);
    
    // if (runnerRecords.isNotEmpty && timingData != null) {
    //   timingData['records'] = await syncBibData(runnerRecords.length, timingData['records'], timingData['endTime'], context);
    //   setState(() {
    //     _runnerRecords = runnerRecords;
    //     _timingData = timingData;
    //     _resultsLoaded = true;
    //     _hasBibConflicts = _containsBibConflicts(runnerRecords);
    //     _hasTimingConflicts = _containsTimingConflicts(timingData);
    //   });
      
    //   await _saveRaceResults();
  }
}