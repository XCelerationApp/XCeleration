import 'package:flutter/material.dart';
import '../../controller/flow_controller.dart';
import '../../../../utils/database_helper.dart';
import '../../../../utils/flow_widget.dart';
import '../../../../utils/enums.dart';
import '../../../../utils/runner_time_functions.dart';
import '../../../../utils/encode_utils.dart';
import '../../../../core/services/device_connection_service.dart';
import '../../../../core/components/device_connection_widget.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';

/// Controller for managing the post-race flow
class PostRaceFlowController extends FlowController {
  // Device connections
  Map<DeviceName, Map<String, dynamic>> deviceConnections = {};
  
  // Results state
  bool resultsLoaded = false;
  List<Map<String, dynamic>>? runnerRecords;
  Map<String, dynamic>? timingData;
  bool hasBibConflicts = false;
  bool hasTimingConflicts = false;
  
  PostRaceFlowController({required int raceId}) : super(raceId: raceId) {
    // Initialize device connections
    _initializeDeviceConnections();
  }
  
  /// Initialize device connections
  void _initializeDeviceConnections() {
    deviceConnections = DeviceConnectionService.createOtherDeviceList(
      DeviceName.coach,
      DeviceType.browserDevice,
    );
  }
  
  /// Start the post-race flow
  Future<bool> startFlow(BuildContext context) async {
    // Create UI components
    final loadResultsScreen = _buildLoadResultsScreen(context);
    final reviewResultsScreen = _buildReviewResultsScreen();
    final saveResultsScreen = _buildSaveResultsScreen();
    
    // Create flow steps
    final steps = await createPostRaceFlowSteps(
      loadResultsScreen,
      reviewResultsScreen,
      saveResultsScreen,
    );
    
    // Show the flow
    final result = await showFlow(
      context: context,
      steps: steps,
      dismissible: true,
    );
    
    // If flow was completed, update the race state
    if (result) {
      await updateFlowStateToFinished();
    }
    
    return result;
  }
  
  /// Build the load results screen
  Widget _buildLoadResultsScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          deviceConnectionWidget(
            DeviceName.coach,
            DeviceType.browserDevice,
            deviceConnections,
          ),
          const SizedBox(height: 24),
          Text(
            resultsLoaded ? 'Results Loaded Successfully!' : 'Connect to devices to load results',
            style: AppTypography.titleMedium.copyWith(
              color: resultsLoaded ? Colors.green : AppColors.darkColor,
            ),
          ),
          if (resultsLoaded) 
            ElevatedButton(
              onPressed: () {
                // Handle received data
                if (deviceConnections[DeviceName.bibRecorder]?['data'] != null && 
                    deviceConnections[DeviceName.raceTimer]?['data'] != null) {
                  processReceivedData(
                    deviceConnections[DeviceName.bibRecorder]?['data'],
                    deviceConnections[DeviceName.raceTimer]?['data'],
                    context
                  );
                }
              },
              child: const Text('Process Received Data'),
            ),
        ],
      ),
    );
  }
  
  /// Build review results screen
  Widget _buildReviewResultsScreen() {
    if (!resultsLoaded) {
      return Center(
        child: Text(
          'Please load results first',
          style: AppTypography.bodyRegular,
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasBibConflicts || hasTimingConflicts)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warnings',
                    style: AppTypography.titleMedium.copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  if (hasBibConflicts)
                    Text(
                      '• There are bib number conflicts that need to be resolved.',
                      style: AppTypography.bodyMedium,
                    ),
                  if (hasTimingConflicts)
                    Text(
                      '• There are timing conflicts that need to be reviewed.',
                      style: AppTypography.bodyMedium,
                    ),
                ],
              ),
            ),
          Text(
            'Race Results Summary',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Total Runners: ${runnerRecords?.length ?? 0}',
            style: AppTypography.bodyRegular,
          ),
          Text(
            'Race Start Time: ${timingData?['startTime'] ?? 'Not available'}',
            style: AppTypography.bodyRegular,
          ),
          Text(
            'Race End Time: ${timingData?['endTime'] ?? 'Not available'}',
            style: AppTypography.bodyRegular,
          ),
        ],
      ),
    );
  }
  
  /// Build save results screen
  Widget _buildSaveResultsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 120, color: Colors.green),
          const SizedBox(height: 32),
          Text(
            'Race Complete!',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'The race results have been saved successfully.',
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  /// Reset results loading state
  void resetResultsLoading() {
    resultsLoaded = false;
    hasBibConflicts = false;
    hasTimingConflicts = false;
    notifyListeners();
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
      hasBibConflicts = containsBibConflicts(processedRunnerRecords);
      hasTimingConflicts = containsTimingConflicts(processedTimingData);
      
      await saveRaceResults();
      notifyListeners();
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
  
  /// Check if there are timing conflicts in the data
  bool containsTimingConflicts(Map<String, dynamic> data) {
    return getConflictingRecords(data['records'], data['records'].length).isNotEmpty;
  }
  
  /// Check if there are bib conflicts in the runner records
  bool containsBibConflicts(List<dynamic> records) {
    return records.any((record) => record['error'] != null);
  }
  
  /// Create flow steps for post-race flow
  Future<List<FlowStep>> createPostRaceFlowSteps(
    Widget loadResultsScreen,
    Widget reviewResultsScreen,
    Widget saveResultsScreen,
  ) async {
    return [
      FlowStep(
        title: 'Load Results',
        description: 'Connect to devices to load race results',
        content: loadResultsScreen,
        canProceed: () async {
          // Check if results are loaded
          if (!resultsLoaded) {
            return false;
          }
          return true;
        },
      ),
      FlowStep(
        title: 'Review Results',
        description: 'Review and resolve any issues with race results',
        content: reviewResultsScreen,
        canProceed: () async {
          // Save results and proceed
          await saveRaceResults();
          return true;
        },
      ),
      FlowStep(
        title: 'Save & Finalize',
        description: 'Finalize race results',
        content: saveResultsScreen,
        canProceed: () async {
          // Update race flow state to finished
          await updateFlowStateToFinished();
          return true;
        },
      ),
    ];
  }
  
  /// Update flow state to finished
  Future<void> updateFlowStateToFinished() async {
    await DatabaseHelper.instance.updateRaceFlowState(raceId, 'finished');
    notifyListeners();
  }
}
