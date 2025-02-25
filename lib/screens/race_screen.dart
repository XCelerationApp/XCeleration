import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:xcelerate/runner_time_functions.dart';
import '../database_helper.dart';
import '../models/race.dart';
import 'runners_management_screen.dart';
import 'results_screen.dart';
import '../utils/UI_components.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../utils/flow_components.dart';
import '../utils/sheet_utils.dart';
import '../utils/enums.dart';
import '../device_connection_popup.dart';
import '../device_connection_service.dart' hide DeviceType;
import 'dart:convert';
import '../utils/encode_utils.dart';
import 'merge_conflicts_screen.dart';
import 'resolve_bib_number_screen.dart';
import 'edit_and_review_screen.dart';
import '../utils/typography.dart';

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
  Race? race;
  bool _raceSetup = false;
  bool _preRaceFinished = false;
  bool _postRaceFinished = false;
  bool _resultsLoaded = false;
  List<Map<String, dynamic>>? _runnerRecords;
  Map<String, dynamic>? _timingData;
  bool _hasBibConflicts = false;
  bool _hasTimingConflicts = false;

  final ValueNotifier<ConnectionStatus> _connectionStatusNotifier = ValueNotifier<ConnectionStatus>(ConnectionStatus.searching);
  final ValueNotifier<ConnectionStatus> _qrConnectionStatusNotifier = ValueNotifier<ConnectionStatus>(ConnectionStatus.searching);
  final ValueNotifier<ConnectionStatus> _bibRecorderStatusNotifier = ValueNotifier<ConnectionStatus>(ConnectionStatus.searching);
  final ValueNotifier<ConnectionStatus> _raceTimerStatusNotifier = ValueNotifier<ConnectionStatus>(ConnectionStatus.searching);

  @override
  void initState() {
    super.initState();
    _loadRace();
  }

  Future<void> _loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(widget.raceId);
    setState(() {
      race = loadedRace;
    });
    _raceSetup = await DatabaseHelper.instance.checkIfRaceRunnersAreLoaded(widget.raceId);
    
    // Load saved results if they exist
    final savedResults = await DatabaseHelper.instance.getRaceResultsData(widget.raceId);
    if (savedResults != null) {
      setState(() {
        _runnerRecords = savedResults['runnerRecords'];
        _timingData = savedResults['timingData'];
        _resultsLoaded = true;
      });
    }
    
    _continueRaceFlow();
  }

  Future<void> _saveRaceResults() async {
    if (_runnerRecords != null && _timingData != null) {
      await DatabaseHelper.instance.saveRaceResults(
        widget.raceId,
        {
          'runnerRecords': _runnerRecords,
          'timingData': _timingData,
        },
      );
    }
  }

  Future<void> _continueRaceFlow() async {
    if (race == null) return;

    switch (race!.flowState) {
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
    if (race == null) return;
    
    switch (race!.flowState) {
      case 'setup':
        await _setupRace(raceId);
        break;
      case 'pre_race':
        await _preRaceSetup(raceId);
        break;
      case 'post_race':
        await _postRaceSetup(raceId);
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

    final isCompleted = await showFlow(
      context: context,
      showProgressIndicator: true,
      steps: [runnersStep, completionStep],
      // dismissible: false,
    );

    if (isCompleted) {
      _raceSetup = await DatabaseHelper.instance.checkIfRaceRunnersAreLoaded(raceId);
      if (_raceSetup) {
        await DatabaseHelper.instance.updateRaceFlowState(raceId, 'pre_race');
        setState(() {
          race = race!.copyWith(flowState: 'pre_race');
        });
        await _preRaceSetup(raceId);
      }
    }
  }

  Future<void> _preRaceSetup(int raceId) async {
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
              onContentChanged: () {},
            )
          ]
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Share Runners',
        description: 'Share the runners with the bib recorders phone before starting the race.',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ValueListenableBuilder<ConnectionStatus>(
              valueListenable: _connectionStatusNotifier,
              builder: (context, status, child) {
                return SearchableButton(
                  label: 'Bib recorder',
                  icon: Icons.person,
                  connectionStatus: status,
                  onTap: () async {
                    final data = await _getEncodedRunnersData();
                    _startDeviceConnection(
                      context,
                      deviceType: DeviceType.advertiserDevice,
                      deviceName: DeviceName.coach,
                      data: data,
                    );
                  },
                  isQrCode: false,
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'or',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<ConnectionStatus>(
              valueListenable: _qrConnectionStatusNotifier,
              builder: (context, status, child) {
                return SearchableButton(
                  label: 'Share QR code',
                  icon: Icons.qr_code,
                  connectionStatus: status,
                  showSearchingText: false,
                  onTap: () async {
                    final data = await _getEncodedRunnersData();
                    _showQRCodeConnection(
                      context,
                      deviceType: DeviceType.advertiserDevice,
                      deviceName: DeviceName.coach,
                      data: data,
                    );
                  },
                  isQrCode: true,
                );
              },
            ),
          ],
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Setup Complete',
        description: 'You\'re ready to start timing the race!',
        content: FlowStepContent(
          title: 'Setup Complete',
          description: 'You\'re ready to start timing the race!',
          currentStep: 1,
          totalSteps: 2,
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(),
                FlowActionButton(
                  label: 'Start Race',
                  onPressed: () {
                    // Handle race start
                  },
                ),
              ],
            ),
          ),
        ),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Start Race',
        description: 'The race is ready to begin. Once the race is finished, click Next to proceed with collecting results.',
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon(
              //   Icons.sports_score,
              //   size: 80,
              //   color: AppColors.primaryColor,
              // ),
              // const SizedBox(height: 24),
              // Text(
              //   'Ready to Start!',
              //   style: TextStyle(
              //     fontSize: 24,
              //     fontWeight: FontWeight.bold,
              //     color: AppColors.darkColor,
              //   ),
              // ),
              // const SizedBox(height: 16),
              // Text(
              //   'Click Next once the race is finished to collect results.',
              //   style: TextStyle(
              //     fontSize: 16,
              //     color: AppColors.darkColor.withOpacity(0.7),
              //   ),
              //   textAlign: TextAlign.center,
              // ),
            ],
          ),
        ),
        canProceed: () async => true,
      ),
    ];

    final isCompleted = await showFlow(
      context: context,
      steps: steps,
      // dismissible: false,
    );

    if (isCompleted) {
      await DatabaseHelper.instance.updateRaceFlowState(raceId, 'post_race');
      setState(() {
        race = race!.copyWith(flowState: 'post_race');
      });
      await _postRaceSetup(raceId);
    }
  }

  Future<void> _postRaceSetup(int raceId) async {
    print('_postRaceSetup');
    print('_resultsLoaded: $_resultsLoaded, _runnerRecords: $_runnerRecords, _hasBibConflicts: $_hasBibConflicts');
    setState(() {
      // _resultsLoaded = _;
      _hasBibConflicts = _resultsLoaded && _runnerRecords != null && _containsBibConflicts(_runnerRecords!);
      _hasTimingConflicts = _resultsLoaded && _timingData != null && _containsTimingConflicts(_timingData!);
      // _hasTimingConflicts = false;
    });

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
                ValueListenableBuilder<ConnectionStatus>(
                  valueListenable: _bibRecorderStatusNotifier,
                  builder: (context, status, child) {
                    return SearchableButton(
                      label: 'Bib Recorder',
                      icon: Icons.person_outline,
                      connectionStatus: status,
                      showSearchingText: true,
                    );
                  }
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<ConnectionStatus>(
                  valueListenable: _raceTimerStatusNotifier,
                  builder: (context, status, child) {
                    return SearchableButton(
                      label: 'Race Timer',
                      icon: Icons.timer_outlined,
                      connectionStatus: status,
                      showSearchingText: true,
                    );
                  }
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
                Container(
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
                        Text(
                          _resultsLoaded ? 'Reload Results' : 'Load Results',
                          style: AppTypography.bodySemibold.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    onPressed: () async {
                      _bibRecorderStatusNotifier.value = ConnectionStatus.searching;
                      _raceTimerStatusNotifier.value = ConnectionStatus.searching;
                      
                      final otherDevices = createOtherDeviceList(
                        DeviceName.coach,
                        DeviceType.browserDevice,
                      );

                      await showDeviceConnectionPopup(
                        context,
                        deviceType: DeviceType.browserDevice,
                        deviceName: DeviceName.coach,
                        otherDevices: otherDevices,
                      );

                      final encodedBibRecords = otherDevices[DeviceName.bibRecorder]?['data'] as String?;
                      final encodedFinishTimes = otherDevices[DeviceName.raceTimer]?['data'] as String?;

                      if (encodedBibRecords != null) {
                        _bibRecorderStatusNotifier.value = ConnectionStatus.finished;
                      }
                      if (encodedFinishTimes != null) {
                        _raceTimerStatusNotifier.value = ConnectionStatus.finished;
                      }

                      if (encodedBibRecords == null || encodedFinishTimes == null) {
                        _bibRecorderStatusNotifier.value = ConnectionStatus.error;
                        _raceTimerStatusNotifier.value = ConnectionStatus.error;
                        return;
                      }
                      
                      var runnerRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
                      final timingData = await processEncodedTimingData(encodedFinishTimes, context);
                      
                      if (runnerRecords.isNotEmpty && timingData != null) {
                        timingData['records'] = await syncBibData(runnerRecords.length, timingData['records'], timingData['endTime'], context);
                        setState(() {
                          _runnerRecords = runnerRecords;
                          _timingData = timingData;
                          _resultsLoaded = true;
                          _hasBibConflicts = _containsBibConflicts(runnerRecords);
                          _hasTimingConflicts = _containsTimingConflicts(timingData);
                        });
                        
                        await _saveRaceResults();
                      }
                    }
                  ),
                ),
              ],
            ),
          ),
        ),
        canProceed: () async => _resultsLoaded && !_hasBibConflicts && !_hasTimingConflicts,
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

    final isCompleted = await showFlow(
      context: context,
      steps: steps,
      // dismissible: false,
    );

    if (isCompleted) {
      await DatabaseHelper.instance.updateRaceFlowState(raceId, 'finished');
      setState(() {
        race = race!.copyWith(flowState: 'finished');
      });
    }
  }

  Future<void> _loadRaceData() async {
    final raceData = await DatabaseHelper.instance.getRaceById(raceId);
    if (raceData != null) {
      setState(() {
        race = raceData;
        _name = race!.race_name;
        _location = race!.location;
        _date = race!.race_date.toString();
        _distance = race!.distance;
        _teamColors = race!.teamColors;
        _teamNames = race!.teams;
        final stringDate = DateTime.parse(race!.race_date.toString()).toIso8601String().split('T').first;

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
    final runners = await DatabaseHelper.instance.getRaceRunners(widget.raceId);
    return runners;
  }

  Future<String> _getEncodedRunnersData() async {
    final runners = await _getRunnersData();
    return jsonEncode(runners);
  }

  bool _containsTimingConflicts(Map<String, dynamic> timingData) {
    return getConflictingRecords(timingData['records'], timingData['records'].length).isNotEmpty;
  }

  bool _containsBibConflicts(List<dynamic> runnerRecords) {
    return runnerRecords.any((record) => record['error'] != null);
  }

  Widget _buildConflictButton(String title, String description, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[100],
          foregroundColor: Colors.red[900],
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red[300]!),
          ),
        ),
        onPressed: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[900]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.bodySemibold.copyWith(color: Colors.red[900]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTypography.bodyRegular.copyWith(color: Colors.red[900]!.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBibConflictsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Resolve Bib Number Conflicts',
                  style: AppTypography.titleSemibold,
                ),
              ),
              Expanded(
                child: ResolveBibNumberScreen(
                  raceId: widget.raceId,
                  records: _runnerRecords!,
                  onComplete: (resolvedRecords) {
                    setState(() {
                      _runnerRecords = resolvedRecords;
                      _hasBibConflicts = false;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    return Future.value();
  }

  Future<void> _showTimingConflictsSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              AppBar(
                title: Text(
                  'Resolve Timing Conflicts',
                  style: AppTypography.titleSemibold,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: MergeConflictsScreen(
                  raceId: widget.raceId,
                  runnerRecords: _runnerRecords!,
                  timingData: _timingData!,
                  onComplete: (resolvedData) {
                    setState(() {
                      _timingData = resolvedData;
                      _hasTimingConflicts = false;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _timingData = result;
        _hasTimingConflicts = false;
      });
      await _saveRaceResults();
    }
  }

  // Future<void> _goToMergeConflictsScreen(context, runnerRecords, timingData) async {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => MergeConflictsScreen(runnerRecords: runnerRecords, timingData: timingData, raceId: raceId),
  //     ),
  //   );
  // }

  _goToEditScreen(context, runnerRecords, timingData) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAndReviewScreen(timingData: timingData, raceId: raceId),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _distanceController.dispose();
    _slideController.dispose();
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

  Widget _buildPageButton(String title, String iconName, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.only(bottom: 20),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        children: [
          if (iconName == 'info') ...[
            Icon(Icons.info, size: 20, color: AppColors.primaryColor),
          ]
          else
            Image.asset('assets/icon/$iconName.png', width: 20, height: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, String iconName, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/icon/$iconName.png', width: 20, height: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceInfo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        createSheetHeader('Race Information', backArrow: true, context: context, onBack: _goBackToMainRaceScreen),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name, 
                style: AppTypography.titleSemibold,
              ),
              const SizedBox(height: 24),
              Text('Teams', 
                style: AppTypography.bodySemibold,
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _teamNames.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _teamColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black12,
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _teamNames[index],
                      style: AppTypography.bodyRegular,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoRow(
                Icons.location_on_outlined,
                _location,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.calendar_today,
                _date.substring(0, 10),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.straighten,
                '$_distance $_distanceUnit',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.black54,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyRegular,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryScreen(Widget content) {
    return Stack(
      children: [
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeInOut,  
          )),
          child: FadeTransition(  
            opacity: CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeIn,
            ),
            child: Material(
              color: AppColors.backgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   content,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (!mounted) return const SizedBox.shrink();

    return FutureBuilder<List<dynamic>>(
      future: DatabaseHelper.instance.getRaceResults(raceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final showResultsButton = snapshot.hasData && snapshot.data!.isNotEmpty;

        if (_showDetails && _slideController.value > 0) {
          return _buildSecondaryScreen(_buildRaceInfo());
        }
        
        if (_showRunners && _slideController.value > 0) {
          return _buildSecondaryScreen(RunnersManagementScreen(
            raceId: raceId,
            onBack: _goBackToMainRaceScreen,
          ));
        }
        
        if (_showResults && _slideController.value > 0) {
          return _buildSecondaryScreen(ResultsScreen(
            raceId: raceId,
            onBack: _goBackToMainRaceScreen,
          ));
        }
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            createSheetHeader(_name),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _buildPageButton('Race Info', 'info', () => _goToDetailsScreen(context)),
                  const SizedBox(height: 12),
                  _buildPageButton('Runners', 'runner', () => _goToRunnersScreen(context)),
                  if (showResultsButton) ...[
                    const SizedBox(height: 12),
                    _buildPageButton('Results', 'flag', () => _goToResultsScreen(context)),
                  ],
                  if (race!.flowState == 'setup' || race!.flowState == 'pre_race') ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (race!.flowState == 'setup') {
                          await _setupRace(raceId);
                        } else {
                          await _preRaceSetup(raceId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        race!.flowState == 'setup' ? 'Setup Race' : 'Continue Race Setup',
                        style: AppTypography.bodySemibold.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkIfRunnersAreLoaded(int raceId) async {
    final race = await DatabaseHelper.instance.getRaceById(raceId);
    final raceRunners = await DatabaseHelper.instance.getRaceRunners(raceId);
    
    // Check if we have any runners at all
    if (raceRunners.isEmpty) {
      return false;
    }

    // Check if each team has at least 2 runners (minimum for a race)
    final teamRunnerCounts = <String, int>{};
    for (final runner in raceRunners) {
      final team = runner['school'] as String;
      teamRunnerCounts[team] = (teamRunnerCounts[team] ?? 0) + 1;
    }

    // Verify each team in the race has enough runners
    for (final teamName in race!.teams) {
      final runnerCount = teamRunnerCounts[teamName] ?? 0;
      if (runnerCount < 5) {
        return false;
      }
    }

    return true;
  }

  Future<void> _showRaceResultsScreen(int raceId) async{
  }

  @override
  Widget build(BuildContext context) {
    if (race == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          race!.race_name,
          style: AppTypography.titleSemibold.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Race status banner
          Container(
            color: _getStatusColor(race!.flowState),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(race!.flowState),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(race!.flowState),
                  style: AppTypography.bodySemibold.copyWith(color: Colors.white),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _continueRaceFlow,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha((0.2 * 255).round()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    'Continue',
                    style: AppTypography.bodySemibold.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Race details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Race Details',
                    style: AppTypography.titleSemibold,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Date', race!.race_date.toString().split(' ')[0]),
                  _buildDetailRow('Location', race!.location),
                  _buildDetailRow('Distance', '${race!.distance} ${race!.distanceUnit}'),
                  _buildDetailRow('Teams', race!.teams.join(', ')),
                  _buildDetailRow('Status', _getStatusText(race!.flowState)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySemibold,
          ),
          Text(value),
        ],
      ),
    );
  }

  Color _getStatusColor(String flowState) {
    switch (flowState) {
      case 'setup':
        return Colors.blue;
      case 'pre_race':
        return Colors.orange;
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
        return Icons.sports_score;
      case 'post_race':
        return Icons.assessment;
      case 'finished':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String flowState) {
    switch (flowState) {
      case 'setup':
        return 'Setting Up';
      case 'pre_race':
        return 'Pre-Race';
      case 'post_race':
        return 'Post-Race';
      case 'finished':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  void _startDeviceConnection(
    BuildContext context, {
    required DeviceType deviceType,
    required DeviceName deviceName,
    required String data,
  }) {
    final otherDevices = createOtherDeviceList(deviceName, deviceType, data: data);
  
    showDeviceConnectionPopup(
      context,
      deviceType: deviceType,
      deviceName: deviceName,
      otherDevices: otherDevices,
    ).then((_) {
      // Reset status after connection is complete
      _connectionStatusNotifier.value = ConnectionStatus.searching;
    });

    // Listen to status changes
    for (var device in otherDevices.entries) {
      if (device.value['status'] != null) {
        _connectionStatusNotifier.value = device.value['status'];
      }
    }
  }

  void _showQRCodeConnection(
    BuildContext context, {
    required DeviceType deviceType,
    required DeviceName deviceName,
    required String data,
  }) {
    final otherDevices = createOtherDeviceList(deviceName, deviceType, data: data);
  
    _qrConnectionStatusNotifier.value = ConnectionStatus.connecting;
  
    showDeviceConnectionPopup(
      context,
      deviceType: deviceType,
      deviceName: deviceName,
      otherDevices: otherDevices,
    ).then((_) {
      // Reset status after connection is complete
      _qrConnectionStatusNotifier.value = ConnectionStatus.searching;
    });
  }
}