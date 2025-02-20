import 'package:flutter/material.dart';
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
  late String _distanceUnit = 'miles';
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

  Widget _buildPageButton(String title, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryColor, size: 24),
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

  Widget _buildActionButton(String title, IconData icon, VoidCallback onPressed) {
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
          Icon(icon, color: AppColors.primaryColor, size: 20),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  SizedBox(width: 20),
                      Row(
                        children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _location,
                          style: TextStyle(
                            overflow: TextOverflow.ellipsis,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                                children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                                  ),
                      const SizedBox(width: 5),
                      Text(
                        _date.substring(0, 10),
                        style: TextStyle(
                          fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 20,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_distance $_distanceUnit',
                        style: TextStyle(
                          fontSize: 15,
                      ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
      ]
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
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.92,
                child: Column(
                  children: [
                    // SizedBox(
                    //   height: 40,
                    //   child: Row(
                    //     children: [
                    //       IconButton(
                    //         icon: const Icon(Icons.arrow_back, color: AppColors.primaryColor, size: 32),
                    //         padding: EdgeInsets.zero,
                    //         constraints: const BoxConstraints(),
                    //         style: ButtonStyle(
                    //           iconColor: WidgetStateProperty.all(AppColors.primaryColor),
                    //         ),
                    //         onPressed: _goBackToMainRaceScreen,
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    Expanded(
                      child: content,
                    ),
                  ],
                ),
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
            isTeam: false,
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
                    //         {'finish_time': '1.02', 'type': 'confirm_runner_number', 'is_confirmed': true, 'text_color': Colors.green, 'numTimes': 2},
                    //         {'finish_time': '1.06', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 3},
                    //         {'finish_time': '1.12', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 4},
                    //         {'finish_time': '1.17', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 5},
                    //         {'finish_time': '1.20', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': ''},
                    //         {'finish_time': '1.21', 'type': 'extra_runner_time', 'offBy': 1, 'numTimes': 5, 'text_color': AppColors.redColor},
                    //         {'finish_time': '1.24', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 6},
                    //         {'finish_time': '1.27', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 7},
                    //         {'finish_time': 'TBD', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 8},
                    //         {'finish_time': '1.60', 'type': 'missing_runner_time', 'text_color': AppColors.redColor, 'numTimes': 8},
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
                    _buildPageButton('See Race Info', Icons.info, () => _goToDetailsScreen(context)),
                    const SizedBox(height: 8),
                    _buildPageButton('See Runners', Icons.person, () => _goToRunnersScreen(context)),
                    if (showResultsButton) ...[
                      const SizedBox(height: 8),
                      _buildPageButton('See Results', Icons.flag, () => _goToResultsScreen(context)),
                    ],
                    if (!showResultsButton) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                'Share Runners',
                                Icons.share,
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            'Receive Results',
                            Icons.download,
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
                ),
                    ],
                  ],
              ),
            )
        ]
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (race == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return IntrinsicHeight(
      child: _buildContent(),
    );
  }
}