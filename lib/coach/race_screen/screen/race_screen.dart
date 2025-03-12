import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xcelerate/assistant/race_timer/timing_screen/model/timing_record.dart' show TimingRecord;
import 'package:xcelerate/utils/runner_time_functions.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
// import '../models/runner.dart';
// import '../models/team.dart';
// import '../device_connection_popup.dart';
// import '../device_connection_service.dart';
// import '../../../utils/UI_components.dart';
import '../../flows/model/flow_model.dart';
// import '../utils/button_utils.dart';
import '../../../utils/encode_utils.dart';
import '../../flows/widgets/flow_components.dart';
import '../../../utils/sheet_utils.dart';
import '../../../utils/enums.dart';
import '../../../core/components/device_connection_widget.dart';
import '../../../core/services/device_connection_service.dart';
// import 'dart:convert';
import '../../../core/theme/typography.dart';
import '../../merge_conflicts_screen/screen/merge_conflicts_screen.dart';
import '../../resolve_bib_number_screen/screen/resolve_bib_number_screen.dart';
import '../../edit_review_screen/screen/edit_and_review_screen.dart';
import '../../runners_management_screen/screen/runners_management_screen.dart';
import '../../results_screen/screen/results_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/conflict_button.dart';
import '../widgets/page_button.dart';
import '../widgets/detail_card.dart';
import '../widgets/modern_detail_row.dart';
import '../widgets/race_status_indicator.dart';
import '../widgets/bib_conflicts_sheet.dart';
import '../widgets/timing_conflicts_sheet.dart';
import '../controller/race_screen_controller.dart';
import '../../merge_conflicts_screen/model/timing_data.dart';
// import '../../../edit_review_screen/model/timing_data.dart';
import '../widgets/runner_record.dart';



class RaceScreen extends StatefulWidget {
  final int raceId;
  const RaceScreen({
    super.key, 
    required this.raceId,
  });

  @override
  RaceScreenState createState() => RaceScreenState();
}

class RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
  late String _name = '';
  late String _location = '';
  late String _date = '';
  late double _distance = 0.0;
  late final String _distanceUnit = 'miles';
  late List<Color> _teamColors = [];
  late List<String> _teamNames = [];
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _dateController;
  late TextEditingController _distanceController;
  late int raceId;
  late AnimationController _slideController;
  bool _showDetails = false;
  bool _showRunners = false;
  bool _showResults = false;
  // Controller
  late RaceScreenController _controller;
  // UI state
  final bool _preRaceFinished = false;
  final bool _postRaceFinished = false;
  bool _raceSetup = false;
  bool _resultsLoaded = false;
  List<Map<String, dynamic>>? _timingRecords;
  TimingData? _timingData;
  bool _hasBibConflicts = false;
  bool _hasTimingConflicts = false;
  
  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
    _controller = RaceScreenController(raceId: widget.raceId);
    _controller.addListener(_updateUI);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadRace();
  }

  void _updateUI() {
    if (!mounted) return;
    setState(() {
      // Update UI variables from controller if needed
      if (_controller.race != null) {
        _name = _controller.race!.race_name;
        _location = _controller.race!.location;
        _date = _controller.race!.race_date.toString();
        _distance = _controller.race!.distance;
        _teamColors = _controller.race!.teamColors;
        _teamNames = _controller.race!.teams;
      }
    });
  }

  Future<void> _loadRace() async {
    await _controller.loadRace();
    setState(() {
      _raceSetup = _controller.raceSetup;
      _resultsLoaded = _controller.resultsLoaded;
      _timingRecords = _controller.timingRecords;
      _timingData = _controller.timingData;
      _hasBibConflicts = _controller.hasBibConflicts;
      _hasTimingConflicts = _controller.hasTimingConflicts;
    });
    _continueRaceFlow();
  }

  Future<void> _saveRaceResults() async {
    await _controller.saveRaceResults();
  }

  Future<void> _continueRaceFlow() async {
    if (_controller.race == null) return;

    switch (_controller.race!.flowState) {
      case 'setup':
        await _setupRace(widget.raceId);
        break;
      case 'pre_race':
        await _preRaceSetup(widget.raceId);
        break;
      case 'post_race':
        await _postRaceSetup(widget.raceId);
        break;
      case 'finished':
        // Show completed state or results
        break;
      default:
        await _setupRace(widget.raceId);
    }
  }

  Future<void> _checkAndStartFlow() async {
    if (_controller.race == null) return;
    
    switch (_controller.race!.flowState) {
      case 'setup':
        await _setupRace(_controller.raceId);
        break;
      case 'pre_race':
        await _preRaceSetup(_controller.raceId);
        break;
      case 'post_race':
        await _postRaceSetup(_controller.raceId);
        break;
      default:
        break;
    }
  }

  Future<void> _setupRace(int raceId) async {
    late final FlowStep runnersStep;
    runnersStep = FlowStep(
      title: 'Load Runners',
      description: 'Add runners to your race by entering their information or importing from a previous race. Each team needs at least 5 runners to proceed.',
      content: RunnersManagementScreen(
        raceId: raceId,
        showHeader: false,
        onBack: null,
        onContentChanged: () => runnersStep.notifyContentChanged(),
      ),
      canProceed: () => _checkIfRunnersAreLoaded(raceId),
    );

    final completionStep = FlowStep(
      title: 'Setup Complete',
      description: 'Great job! You\'ve finished setting up your race. Click Next to begin the pre-race preparations.',
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 120, color: AppColors.primaryColor),
            const SizedBox(height: 32),
            Text(
              'Race Setup Complete!',
              style: AppTypography.titleSemibold.copyWith(color: AppColors.darkColor),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re ready to start managing your race.',
              style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
      canProceed: () async => true,
    );

    final steps = [runnersStep, completionStep];
    final isCompleted = await _controller.setupRace(context, steps);

    if (isCompleted) {
      _raceSetup = await _controller.checkIfRunnersAreLoaded();
      if (_raceSetup) {
        await _controller.updateRaceFlowState('pre_race');
        await _preRaceSetup(raceId);
      }
      else {
        debugPrint('No runners loaded');
      }
    }
    else {
      debugPrint('Setup incomplete');
    }
  }

  Future<void> _preRaceSetup(int raceId) async {
    final otherDevices = _controller.createDeviceConnectionList(
      DeviceType.advertiserDevice,
      data: '',
    );
    
    final steps = [
      FlowStep(
        title: 'Review Runners',
        description: 'Make sure all runner information is correct before the race starts. You can make any last-minute changes here.',
        content: Column(
          children: [
            RunnersManagementScreen(
              raceId: raceId, 
              showHeader: false, 
              onBack: null, 
              onContentChanged: () async {
                final encoded = await _controller.getEncodedRunnersData();
                otherDevices[DeviceName.bibRecorder]!['data'] = encoded;
              },
            )
          ]
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Share Runners',
        description: 'Share the runners with the bib recorders phone before starting the race.',
        content: Center(
          child: deviceConnectionWidget(
            DeviceName.coach,
            DeviceType.advertiserDevice,
            otherDevices,
          )
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Ready to Start!',
        description: 'The race is ready to begin. Click Next once the race is finished to begin the post-race flow.',
        content: SizedBox.shrink(),
        canProceed: () async => true,
      ),
    ];

    final isCompleted = await _controller.preRaceSetup(context, steps);

    if (isCompleted) {
      await _controller.updateRaceFlowState('post_race');
      await _postRaceSetup(raceId);
    }
  }

  Future<void> _postRaceSetup(int raceId) async {
    print('_postRaceSetup');
    setState(() {
      _resultsLoaded = _controller.resultsLoaded;
      _timingRecords = _controller.timingRecords;
      _timingData = _controller.timingData;
      _hasBibConflicts = _resultsLoaded && _timingRecords != null && _controller.containsBibConflicts(_timingRecords!);
      _hasTimingConflicts = _resultsLoaded && _timingData != null && _controller.containsTimingConflicts(_timingData!);
    });

    Map<DeviceName, Map<String, dynamic>> otherDevices = _controller.createDeviceConnectionList(
      DeviceType.browserDevice,
    );

    final steps = [
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
                      
                    //   var timingRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
                    //   final timingData = await processEncodedTimingData(encodedFinishTimes, context);
                      
                    //   if (timingRecords.isNotEmpty && timingData != null) {
                    //     timingData['records'] = await syncBibData(timingRecords.length, timingData['records'], timingData['endTime'], context);
                    //     setState(() {
                    //       _timingRecords = timingRecords;
                    //       _timingData = timingData;
                    //       _resultsLoaded = true;
                    //       _hasBibConflicts = _containsBibConflicts(timingRecords);
                    //       _hasTimingConflicts = _containsTimingConflicts(timingData);
                    //     });
                        
                    //     await _saveRaceResults();
                    //   }
                    // }
                  ),
                ),
                const SizedBox(height: 24),
                if (_resultsLoaded) ...[
                  if (_hasBibConflicts) ...[
                    _buildConflictButton(
                      'Bib Number Conflicts',
                      'Some runners have conflicting bib numbers. Please resolve these conflicts before proceeding.',
                      () => _showBibConflictsSheet(context),
                    ),
                  ]
                  else if (_hasTimingConflicts) ...[
                    _buildConflictButton(
                      'Timing Conflicts',
                      'There are conflicts in the race timing data. Please review and resolve these conflicts.',
                      () => _showTimingConflictsSheet(),
                    ),
                  ],
                  if (!_hasBibConflicts && !_hasTimingConflicts) ...[
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

                _resultsLoaded ? Container(
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
                      setState(() {
                        _resultsLoaded = false;
                        _hasBibConflicts = false;
                        _hasTimingConflicts = false;
                      });
                      _controller.resetResultsLoading();
                      otherDevices = _controller.createDeviceConnectionList(DeviceType.browserDevice);
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
    
    // var timingRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
    // final timingData = await processEncodedTimingData(encodedFinishTimes, context);
    
    // if (timingRecords.isNotEmpty && timingData != null) {
    //   timingData['records'] = await syncBibData(timingRecords.length, timingData['records'], timingData['endTime'], context);
    //   setState(() {
    //     _timingRecords = timingRecords;
    //     _timingData = timingData;
    //     _resultsLoaded = true;
    //     _hasBibConflicts = _containsBibConflicts(timingRecords);
    //     _hasTimingConflicts = _containsTimingConflicts(timingData);
    //   });
      
    //   await _saveRaceResults();

    final isCompleted = await showFlow(
      context: context,
      steps: steps,
      // dismissible: false,
    );

    if (isCompleted) {
      await _controller.updateRaceFlowState('finished');
    }
  }

  Future<void> _loadRaceData() async {
    final raceData = await DatabaseHelper.instance.getRaceById(raceId);
    if (raceData != null) {
      setState(() {
        _controller.race = raceData;
        _name = _controller.race!.race_name;
        _location = _controller.race!.location;
        _date = _controller.race!.race_date.toString();
        _distance = _controller.race!.distance;
        _teamColors = _controller.race!.teamColors;
        _teamNames = _controller.race!.teams;
        final stringDate = DateTime.parse(_controller.race!.race_date.toString()).toIso8601String().split('T').first;

        _nameController = TextEditingController(text: _name);
        _locationController = TextEditingController(text: _location);
        _dateController = TextEditingController(text: stringDate);
        _distanceController = TextEditingController(text: _distance.toString());
      });
    }
    else {
      debugPrint('raceData is null');
    }
  }

  Future<List<dynamic>> _getRunnersData() async {
    return await _controller.getRunnersData();
  }

  Future<String> _getEncodedRunnersData() async {
    return await _controller.getEncodedRunnersData();
  }

  bool _containsTimingConflicts(TimingData timingData) {
    return _controller.containsTimingConflicts(timingData);
  }

  bool _containsBibConflicts(List<RunnerRecord> runnerRecords) {
    return _controller.containsBibConflicts(runnerRecords);
  }

  Widget _buildConflictButton(String title, String description, VoidCallback onPressed) {
    return ConflictButton(
      title: title,
      description: description,
      onPressed: onPressed,
    );
  }

  Widget _buildModernDetailRow(String label, String value, IconData icon, {bool isMultiLine = false}) {
    return ModernDetailRow(
      label: label,
      value: value,
      icon: icon,
      isMultiLine: isMultiLine,
    );
  }

  String _getStatusText(String flowState) {
    switch (flowState) {
      case 'setup':
        return 'Setup';
      case 'pre_race':
        return 'Pre-Race';
      case 'post_race':
        return 'Post-Race';
      case 'finished':
        return 'Finished';
      default:
        return 'Unknown';
    }
  }

  Future<void> _handleReceivedData(String? bibRecordsData, String? finishTimesData) async {
    await _controller.processReceivedData(bibRecordsData, finishTimesData, context);
    setState(() {
      _timingRecords = _controller.timingRecords;
      _timingData = _controller.timingData;
      _resultsLoaded = _controller.resultsLoaded;
      _hasBibConflicts = _controller.hasBibConflicts;
      _hasTimingConflicts = _controller.hasTimingConflicts;
    });
  }

  Future<void> _showBibConflictsSheet(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibConflictsSheet(runnerRecords: _timingData!.runnerRecords),
    );
  }

  Future<void> _showTimingConflictsSheet() async {
    final List<RunnerRecord> conflictingRecords = getConflictingRecords(_timingData!.records, _timingData!.records.length);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TimingConflictsSheet(
        conflictingRecords: conflictingRecords,
        timingData: _timingData!,
        runnerRecords: _timingData!.runnerRecords,
        raceId: widget.raceId,
      ),
    );
  }

  Future<void> _goToEditScreen(context, timingRecords, timingData) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAndReviewScreen(timingData: timingData, raceId: raceId),
      ),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _distanceController.dispose();
    _controller.removeListener(_updateUI);
    super.dispose();
  }

  void _goToDetailsScreen(BuildContext context) {
    setState(() {
      _showDetails = true;
    });
    _slideController.forward();
  }

  void _goToRunnersScreen(BuildContext context) {
    setState(() {
      _showRunners = true;
    });
    _slideController.forward();
  }

  void _goToResultsScreen(BuildContext context) {
    setState(() {
      _showResults = true;
    });
    _slideController.forward();
  }

  void _goBackToMainRaceScreen() {
    _slideController.reverse().then((_) {
      setState(() {
        _showRunners = false;
        _showResults = false;
        _showDetails = false;
      });
    });
  }

  Color _getStatusColor(String flowState) {
    switch (flowState) {
      case 'setup':
        return Colors.amber;
      case 'pre_race':
        return Colors.blue;
      case 'post_race':
        return Colors.purple;
      case 'finished':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String flowState) {
    switch (flowState) {
      case 'setup':
        return Icons.settings;
      case 'pre_race':
        return Icons.timer;
      case 'post_race':
        return Icons.flag;
      case 'finished':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Future<bool> _checkIfRunnersAreLoaded(int raceId) async {
    return await _controller.checkIfRunnersAreLoaded();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.race == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rounded header with gradient background
          Container(
            constraints: const BoxConstraints(
              minHeight: 50, // Reduced height
              maxHeight: 70, // Reduced max height
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryColor,
                  AppColors.primaryColor,
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)), // Increased rounding
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle at the top
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8), // Reduced margin
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Race name
                Text(
                  _controller.race!.race_name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22, // Reduced font size
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Action button area - updated color
          Container(
            color: AppColors.primaryColor, // Using primary color instead of blue
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16), // Reduced padding
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 14, // Reduced icon size
                  ),
                ),
                const SizedBox(width: 8), // Reduced spacing
                const Text(
                  'Setting Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14, // Reduced font size
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16), // Reduced radius
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16), // Reduced radius
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _continueRaceFlow,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Reduced padding
                          child: Text(
                            'Continue',
                            style: TextStyle(
                              color: AppColors.primaryColor, // Match primary color
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Reduced font size
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Race details content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7F7),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16), // Reduced padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_controller.race != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: RaceStatusIndicator(flowState: _controller.race!.flowState),
                        ),
                      ],
                      const Text(
                        'Race Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Reduced font size
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16), // Reduced spacing
                      _buildModernDetailRow(
                        'Date',
                        _controller.race!.race_date.toString().split(' ')[0],
                        Icons.calendar_today_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailRow(
                        'Location',
                        _controller.race!.location,
                        Icons.location_on_rounded,
                        isMultiLine: true,
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailRow(
                        'Distance',
                        '${_controller.race!.distance} ${_controller.race!.distanceUnit}',
                        Icons.straighten_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildModernDetailRow(
                        'Teams',
                        _controller.race!.teams.join(', '),
                        Icons.group_rounded,
                      ),
                      // Status section removed
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}