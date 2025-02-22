import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
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
import 'dart:convert';
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
  _RaceScreenState createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> with TickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    raceId = widget.raceId;
    _loadRaceData();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),  
      vsync: this,
    );
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
      print('raceData is null');
    }
  }

  Future<List<dynamic>> _getRunnersData() async {
    final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
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
              // SizedBox(height: 8),
              SingleChildScrollView(
                child: Column(
                  children: [
                    // const SizedBox(height: 10),
                    // _buildActionButton('Merge Conflicts', () => _goToMergeConflictsScreen(
                    //     context, 
                    //     [
                    //       {'bib_number': '1', 'name': 'Teo Donnelley', 'grade': 11, 'school': 'AW', 'error': null},
                    //       {'bib_number': '2', 'name': 'Bill', 'grade': 10, 'school': 'TL', 'error': null},
                    //       {'bib_number': '3', 'name': 'Ethan', 'grade': 12, 'school': 'SR', 'error': null},
                    //       {'bib_number': '4', 'name': 'John', 'grade': 9, 'school': 'SR', 'error': null},
                    //       {'bib_number': '5', 'name': 'Sally', 'grade': 8, 'school': 'SR', 'error': null},
                    //       {'bib_number': '6', 'name': 'Jane', 'grade': 7, 'school': 'SR', 'error': null},
                    //       {'bib_number': '7', 'name': 'Bob', 'grade': 6, 'school': 'SR', 'error': null},
                    //       {'bib_number': '8', 'name': 'Charlie', 'grade': 5, 'school': 'SR', 'error': null},
                    //     ], 
                    //     {
                    //       'endTime': '2.84',
                    //       'records': [
                    //         {'finish_time': '0.45', 'type': 'runner_time', 'is_confirmed': true, 'text_color': null, 'place': 1},
                    //         {'finish_time': '0.83', 'type': 'runner_time', 'is_confirmed': true, 'text_color': null, 'place': 2},
                    //         {'finish_time': '1.02', 'type': 'confirm_runner_number', 'is_confirmed': true, 'text_color': Colors.green, 'place': 3},
                    //         {'finish_time': '1.06', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 4},
                    //         {'finish_time': '1.12', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 5},
                    //         {'finish_time': '1.17', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 6},
                    //         {'finish_time': '1.20', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': ''},
                    //         {'finish_time': '1.21', 'type': 'extra_runner_time', 'offBy': 1, 'numTimes': 5, 'text_color': AppColors.redColor},
                    //         {'finish_time': '1.24', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 7},
                    //         {'finish_time': '1.27', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 8},
                    //         {'finish_time': 'TBD', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 9},
                    //         {'finish_time': '1.60', 'type': 'missing_runner_time', 'text_color': AppColors.redColor, 'numTimes': 10},
                    //       ],
                    //       'startTime': null,
                    //     }
                    //   ),
                    // ),
                    // const SizedBox(height: 10),
                    // _buildActionButton(
                    //   'Resolve Bibs',
                    //   () => _goToTestResolveBibNumbesScreen(
                    //     context, 
                    //     [
                    //       {'bib_number': '1', 'name': 'Teo Donnelley', 'grade': 11, 'school': 'AW', 'error': null},
                    //       {'bib_number': '2', 'name': 'Bill', 'grade': 10, 'school': 'TL', 'error': null},
                    //       {'bib_number': '300', 'name': 'Unknown', 'grade': null, 'school': 'Unknown School', 'error': 'Unknown Runner'},
                    //       {'bib_number': '301', 'name': 'Unknown', 'grade': null, 'school': 'Unknown School', 'error': 'Unknown Runner'},
                    //     ], 
                    //   ),
                    // ),
                    // const SizedBox(height: 10),
                    _buildPageButton('Race Info', 'info', () => _goToDetailsScreen(context)),
                    // const SizedBox(height: 8),
                    _buildPageButton('Runners', 'runner', () => _goToRunnersScreen(context)),
                    if (showResultsButton) ...[
                      // const SizedBox(height: 8),
                      _buildPageButton('Results', 'flag', () => _goToResultsScreen(context)),
                    ],
                    if (!showResultsButton) ...[
                      // const SizedBox(height: 8),
                      Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'Share Runners',
                                'share',
                                () async {
                              final data = await _getEncodedRunnersData();
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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Receive Results',
                            'receive',
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
                              if (encodedBibRecords == null || encodedFinishTimes == null) return;
                              
                              var runnerRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
                              final timingData = await processEncodedTimingData(encodedFinishTimes, context);
                              
                              if (runnerRecords.isNotEmpty && timingData != null) {
                                timingData['records'] = await syncBibData(runnerRecords.length, timingData['records'], timingData['endTime'], context);
                                Navigator.pop(context);
                                if (_containsBibConflicts(runnerRecords)) {
                                  runnerRecords = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ResolveBibNumberScreen(records: runnerRecords, raceId: raceId),
                                    ),
                                  );
                                }
                                final bool conflicts = await _containsTimingConflicts(timingData);
                                if (conflicts) {
                                  _goToMergeConflictsScreen(context, runnerRecords, timingData);
                                } else {
                                  timingData['records'] = timingData['records'].where((r) => r['type'] == 'runner_time').toList();
                                  _goToEditScreen(context, runnerRecords, timingData);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  // ],
                // ),
                    ],
                  ],
              ),
            )
        ]
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

  @override
  Widget build(BuildContext context) {
    if (race == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    late final FlowStep runnersStep;
    runnersStep = FlowStep(
      title: 'Load Runners',
      content: RunnersManagementScreen(
        raceId: raceId,
        showHeader: false,
        onBack: null,
        onContentChanged: () => runnersStep.notifyContentChanged(),
      ),
      canProceed: () => _checkIfRunnersAreLoaded(raceId),
    );

    final steps = [
      runnersStep,
      FlowStep(
        title: 'Share Runners',
        content: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Before the race starts, share\nthe runners with the bib\nrecorders phone.',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            SvgPicture.asset('assets/icon/radio.svg', color: AppColors.primaryColor, width: 300, height: 300),
            SizedBox(width: 8),
            // Share runners button
            ElevatedButton(
              onPressed: () async {
                final data = await _getEncodedRunnersData();
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
                minimumSize: Size(300, 75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/icon/share.svg', color: Colors.white, width: 32, height: 32),
                  SizedBox(width: 8),
                  Text(
                    'Share runners',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
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
        title: 'Load Race Results',
        content: Text('Load Race Results'),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Resolve Bib Conflicts',
        content: Text('Resolve Bib Conflicts'),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Merge Conflicts',
        content: Text('Merge Conflicts'),
        canProceed: () async => true,
      ),
      FlowStep(
        title: 'Results',
        content: Text('Results'),
        canProceed: () async => true,
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showFlow(
        context: context,
        steps: steps,
      );
      Navigator.pop(context);
    });

    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}