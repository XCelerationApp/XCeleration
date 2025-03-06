import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:xcelerate/utils/runner_time_functions.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
// import '../models/runner.dart';
// import '../models/team.dart';
// import '../device_connection_popup.dart';
// import '../device_connection_service.dart';
// import '../../../utils/UI_components.dart';
import '../../../core/components/ui_components.dart';
// import '../utils/button_utils.dart';
import '../../../utils/encode_utils.dart';
import '../../../core/components/flow_components.dart';
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
  final bool _preRaceFinished = false;
  final bool _postRaceFinished = false;
  bool _resultsLoaded = false;
  List<Map<String, dynamic>>? _runnerRecords;
  Map<String, dynamic>? _timingData;
  bool _hasBibConflicts = false;
  bool _hasTimingConflicts = false;
  
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
      else {
        debugPrint('No runners loaded');
      }
    }
    else {
      debugPrint('Setup incomplete');
    }
  }

  Future<void> _preRaceSetup(int raceId) async {
    final otherDevices = DeviceConnectionService.createOtherDeviceList(
      DeviceName.coach,
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
              onContentChanged: () {
                otherDevices[DeviceName.bibRecorder]!['data'] = _getEncodedRunnersData();
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

    Map<DeviceName, Map<String, dynamic>> otherDevices = DeviceConnectionService.createOtherDeviceList(
      DeviceName.coach,
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
                      otherDevices = DeviceConnectionService.createOtherDeviceList(DeviceName.coach, DeviceType.browserDevice);
                    }
                  ),
                ) : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        canProceed: () async => true,
        // canProceed: () async => _resultsLoaded && !_hasBibConflicts && !_hasTimingConflicts,
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
    return runners.map((runner) => [
      runner['bib_number'],
      runner['name'],
      runner['school'],
      runner['grade']
    ].join(',')).join(' ');
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
        // Modern header with gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryColor,
                AppColors.primaryColor.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: _goBackToMainRaceScreen,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(race?.flowState ?? 'setup'), 
                          color: Colors.white, 
                          size: 16
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(race?.flowState ?? 'setup'),
                          style: AppTypography.bodySmall.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _name,
                style: AppTypography.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),
        
        // Content area with card design
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Race Details Card
                _buildCard(
                  'Race Details',
                  Column(
                    children: [
                      _buildDetailItem(
                        'Date',
                        _date.substring(0, 10),
                        Icons.calendar_today_rounded,
                      ),
                      const Divider(height: 24),
                      _buildDetailItem(
                        'Location',
                        _location,
                        Icons.location_on_rounded,
                        isMultiLine: true,
                      ),
                      const Divider(height: 24),
                      _buildDetailItem(
                        'Distance',
                        '$_distance $_distanceUnit',
                        Icons.straighten_rounded,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Teams Card
                _buildCard(
                  'Teams',
                  Column(
                    children: [
                      for (int i = 0; i < _teamNames.length; i++) ... [
                        if (i > 0) const Divider(height: 24),
                        _buildTeamItem(_teamNames[i], _teamColors[i]),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goBackToMainRaceScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, Widget content) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              title,
              style: AppTypography.bodySemibold.copyWith(
                fontSize: 18,
                color: AppColors.darkColor,
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {bool isMultiLine = false}) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkColor,
                ),
                maxLines: isMultiLine ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamItem(String teamName, Color teamColor) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: teamColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          teamName,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.darkColor,
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
                  race!.race_name,
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
                      const Text(
                        'Race Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18, // Reduced font size
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 16), // Reduced spacing
                      _buildDetailCard(
                        'Date',
                        race!.race_date.toString().split(' ')[0],
                        Icons.calendar_today_rounded,
                        Color(0xFFFFECE8), // Lighter background
                        AppColors.primaryColor, // New icon color
                      ),
                      const SizedBox(height: 16),
                      _buildDetailCard(
                        'Location',
                        race!.location,
                        Icons.location_on_rounded,
                        Color(0xFFFFECE8), // Lighter background
                        AppColors.primaryColor, // New icon color
                        isMultiLine: true,
                      ),
                      const SizedBox(height: 16),
                      _buildDetailCard(
                        'Distance',
                        '${race!.distance} ${race!.distanceUnit}',
                        Icons.straighten_rounded,
                        Color(0xFFFFECE8), // Lighter background
                        AppColors.primaryColor, // New icon color
                      ),
                      const SizedBox(height: 16),
                      _buildDetailCard(
                        'Teams',
                        race!.teams.join(', '),
                        Icons.group_rounded,
                        Color(0xFFFFECE8), // Lighter background
                        AppColors.primaryColor, // New icon color
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

  Widget _buildDetailCard(String label, String value, IconData icon, Color bgColor, Color iconColor, {bool isMultiLine = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                    maxLines: isMultiLine ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDetailRow(String label, String value, IconData icon, {bool isMultiLine = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkColor,
                  ),
                  maxLines: isMultiLine ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
}