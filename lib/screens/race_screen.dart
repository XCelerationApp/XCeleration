import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xcelerate/runner_time_functions.dart';
import '../database_helper.dart';
import '../models/race.dart';
import 'runners_management_screen.dart';
import 'results_screen.dart';
import '../utils/sheet_utils.dart';
import '../utils/app_colors.dart'; // Import AppColors
import '../device_connection_popup.dart';
// import '../utils/dialog_utils.dart';
import '../device_connection_service.dart';
import '../utils/encode_utils.dart';
import 'merge_conflicts_screen.dart';
import 'resolve_bib_number_screen.dart';
import 'edit_and_review_screen.dart';
import '../utils/ui_components.dart';

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
            SvgPicture.asset(
              'assets/icon/checkmark.svg',
              width: 120,
              height: 120,
              colorFilter: ColorFilter.mode(AppColors.primaryColor, BlendMode.srcIn),
            ),
            const SizedBox(height: 32),
            Text(
              'Race Setup Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.darkColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re ready to start managing your race.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkColor.withAlpha((0.7 * 255).round()),
              ),
            ),
          ],
        ),
      ),
      canProceed: () async => true,
    );

    final isCompleted = await showFlow(
      context: context,
      showProgressIndicator: false,
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
        description: 'Share the runner list with the bib recorder\'s phone. This is required for tracking runners during the race.',
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icon/radio.svg', 
              colorFilter: ColorFilter.mode(AppColors.primaryColor, BlendMode.srcIn), 
              width: 200, 
              height: 200
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final data = await _getEncodedRunnersData();
                if (!mounted) return;
                showDeviceConnectionPopup(
                  context,
                  deviceType: DeviceType.advertiserDevice,
                  deviceName: DeviceName.coach,
                  otherDevices: createOtherDeviceList(
                    DeviceName.coach,
                    DeviceType.advertiserDevice,
                    data: data,
                  ),
                );
              },
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
                  SvgPicture.asset(
                    'assets/icon/share.svg', 
                    colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn), 
                    width: 24, 
                    height: 24
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Share Runners',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    setState(() {
      _resultsLoaded = false;
    });

    final steps = [
      FlowStep(
        title: 'Load Results',
        description: 'Load the results of the race from the assistant devices.',
        content:
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icon/radio.svg', 
              colorFilter: ColorFilter.mode(AppColors.primaryColor, BlendMode.srcIn), 
              width: 200, 
              height: 200
            ),
            const SizedBox(height: 24),
            if (_resultsLoaded) ...[
              Text(
                'Results Loaded',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can proceed to review the results or load them again if needed.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.darkColor.withAlpha((0.7 * 255).round()),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              onPressed:
              () async {
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
                final encodedBibRecords = otherDevices[DeviceName.bibRecorder]!['data'];
                final encodedFinishTimes = otherDevices[DeviceName.raceTimer]!['data'];
                if (encodedBibRecords == null || encodedFinishTimes == null || !mounted) return;
                var runnerRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
                if (!mounted) return;
                final timingData = await processEncodedTimingData(encodedFinishTimes, context);
                
                if (runnerRecords.isNotEmpty && timingData != null && mounted) {
                  timingData['records'] = await syncBibData(runnerRecords.length, timingData['records'], timingData['endTime'], context);
                  if (!mounted) return;
                  Navigator.pop(context);
                  if (_containsBibConflicts(runnerRecords)) {
                    runnerRecords = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ResolveBibNumberScreen(records: runnerRecords, raceId: raceId),
                      ),
                    );
                  }
                  final bool conflicts = _containsTimingConflicts(timingData);
                  if (!mounted) return;
                  if (conflicts) {
                    _goToMergeConflictsScreen(context, runnerRecords, timingData);
                  } else {
                    timingData['records'] = timingData['records'].where((r) => r['type'] == 'runner_time').toList();
                    _goToEditScreen(context, runnerRecords, timingData);
                  }
                  setState(() {
                    _runnerRecords = runnerRecords;
                    _timingData = timingData;
                    _resultsLoaded = true;
                  });
                  await _saveRaceResults();
                }
              }
            )]),
        canProceed: () async => _resultsLoaded,
      ),
      FlowStep(
        title: 'Review Results',
        description: 'Review and verify the race results before saving them.',
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fact_check_outlined,
                size: 80,
                color: AppColors.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Review Race Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Make sure all times and placements are correct.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.darkColor.withAlpha((0.7 * 255).round()),
                ),
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
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkColor),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text('Runner', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkColor),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('Time', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkColor),
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
              Icon(
                Icons.save_outlined,
                size: 80,
                color: AppColors.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Save Race Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Click Next to save the results and complete the race.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.darkColor.withAlpha((0.7 * 255).round()),
                ),
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
    final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
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


  // _goToTestResolveBibNumbesScreen(context, records) async {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => ResolveBibNumberScreen(records: records, raceId: raceId),
  //     ),
  //   );
  // }
  
  Future<void> _goToMergeConflictsScreen(context, runnerRecords, timingData) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MergeConflictsScreen(runnerRecords: runnerRecords, timingData: timingData, raceId: raceId),
      ),
    );
  }

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
            SvgPicture.asset('assets/icon/$iconName.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(AppColors.primaryColor, BlendMode.srcIn)),
          ]
          else
            Image.asset('assets/icon/$iconName.png', width: 20, height: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.darkColor,
                fontWeight: FontWeight.w500,
              ),
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
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkColor,
              fontWeight: FontWeight.w500,
            ),
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
                style: const TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                )
              ),
              const SizedBox(height: 24),
              Text('Teams', 
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                )
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
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
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
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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
        title: Text(race!.race_name),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _continueRaceFlow,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha((0.2 * 255).round()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
                    style: Theme.of(context).textTheme.headlineSmall,
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
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
}