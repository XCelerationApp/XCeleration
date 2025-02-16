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

class RaceInfoScreen extends StatefulWidget {
  final int raceId;
  const RaceInfoScreen({
    super.key, 
    required this.raceId,
  });

  @override
  _RaceInfoScreenState createState() => _RaceInfoScreenState();
}

class _RaceInfoScreenState extends State<RaceInfoScreen> with TickerProviderStateMixin {
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


  _goToTestResolveBibNumbesScreen(context, records) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResolveBibNumberScreen(records: records, raceId: raceId),
      ),
    );
  }
  
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

  Widget _buildActionButton(String title, VoidCallback onPressed, {bool showArrow = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: () => onPressed(),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(width: 2, color: Colors.grey),
          ),
          elevation: 2,
          fixedSize: const Size(300, 70),
          backgroundColor: AppColors.backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              Text(title, style: TextStyle(fontSize: 25, color: AppColors.darkColor), textAlign: TextAlign.center),
              const Spacer(),
              if (showArrow) ...[
                Icon(
                  Icons.arrow_forward_ios, 
                  color: AppColors.darkColor,
                  size: 30,
                )
              ]
            ]
          ),
        ),
      )
    );
  }

  Widget _buildRaceInfo() {
    return Row(
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
                  Text(
                    _location,
                    style: TextStyle(
                      fontSize: 15,
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
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 8,
                    child: SizedBox(
                      height: 40,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: AppColors.primaryColor, size: 40),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        style: ButtonStyle(
                          iconColor: WidgetStateProperty.all(AppColors.primaryColor),
                        ),
                        onPressed: _goBackToMainRaceScreen,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: content,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final screenHeight = MediaQuery.of(context).size.height;
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
          return _buildSecondaryScreen(RunnersManagementScreen(isTeam: false, raceId: raceId));
        }
        
        if (_showResults && _slideController.value > 0) {
          return _buildSecondaryScreen(ResultsScreen(raceId: raceId));
        }
        
        return SizedBox(
          width: double.infinity,
          height: screenHeight * 0.92,
          child: Column(
            children: [
              SizedBox(height: 10),
              createSheetHandle(height: 10, width: 60),
              SizedBox(height: 10),
              Center(
                child: Text(
                  _name,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                )
              ),
              SizedBox(height: 10),
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildActionButton('Merge Conflicts', () => _goToMergeConflictsScreen(
                        context, 
                        [
                          {'bib_number': '1', 'name': 'Teo Donnelley', 'grade': 11, 'school': 'AW', 'error': null},
                          {'bib_number': '2', 'name': 'Bill', 'grade': 10, 'school': 'TL', 'error': null},
                          {'bib_number': '3', 'name': 'Ethan', 'grade': 12, 'school': 'SR', 'error': null},
                          {'bib_number': '4', 'name': 'John', 'grade': 9, 'school': 'SR', 'error': null},
                          {'bib_number': '5', 'name': 'Sally', 'grade': 8, 'school': 'SR', 'error': null},
                          {'bib_number': '6', 'name': 'Jane', 'grade': 7, 'school': 'SR', 'error': null},
                          {'bib_number': '7', 'name': 'Bob', 'grade': 6, 'school': 'SR', 'error': null},
                          {'bib_number': '8', 'name': 'Charlie', 'grade': 5, 'school': 'SR', 'error': null},
                        ], 
                        {
                          'endTime': '2.84',
                          'records': [
                            {'finish_time': '0.45', 'type': 'runner_time', 'is_confirmed': true, 'text_color': null, 'place': 1},
                            {'finish_time': '0.83', 'type': 'runner_time', 'is_confirmed': true, 'text_color': null, 'place': 2},
                            {'finish_time': '1.02', 'type': 'confirm_runner_number', 'is_confirmed': true, 'text_color': Colors.green, 'numTimes': 2},
                            {'finish_time': '1.06', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 3},
                            {'finish_time': '1.12', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 4},
                            {'finish_time': '1.17', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 5},
                            {'finish_time': '1.20', 'type': 'runner_time', 'conflict': 'extra_runner_time', 'is_confirmed': false, 'text_color': null, 'place': ''},
                            {'finish_time': '1.21', 'type': 'extra_runner_time', 'offBy': 1, 'numTimes': 5, 'text_color': AppColors.redColor},
                            {'finish_time': '1.24', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 6},
                            {'finish_time': '1.27', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 7},
                            {'finish_time': 'TBD', 'type': 'runner_time', 'conflict': 'missing_runner_time', 'is_confirmed': false, 'text_color': null, 'place': 8},
                            {'finish_time': '1.60', 'type': 'missing_runner_time', 'text_color': AppColors.redColor, 'numTimes': 8},
                          ],
                          'startTime': null,
                        }
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildActionButton(
                      'Resolve Bibs',
                      () => _goToTestResolveBibNumbesScreen(
                        context, 
                        [
                          {'bib_number': '1', 'name': 'Teo Donnelley', 'grade': 11, 'school': 'AW', 'error': null},
                          {'bib_number': '2', 'name': 'Bill', 'grade': 10, 'school': 'TL', 'error': null},
                          {'bib_number': '300', 'name': 'Unknown', 'grade': null, 'school': 'Unknown School', 'error': 'Unknown Runner'},
                          {'bib_number': '301', 'name': 'Unknown', 'grade': null, 'school': 'Unknown School', 'error': 'Unknown Runner'},
                        ], 
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildActionButton('See Race Info', () => _goToDetailsScreen(context)),
                    const SizedBox(height: 10),
                    _buildActionButton('See Runners', () => _goToRunnersScreen(context)),
                    if (showResultsButton) ...[
                      const SizedBox(height: 10),
                      _buildActionButton('See Results', () => _goToResultsScreen(context)),
                    ],
                    if (!showResultsButton) ...[
                      const SizedBox(height: 10),
                      _buildActionButton(
                        'Share Runners',
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
                        showArrow: false
                      ),
                      const SizedBox(height: 10),
                      _buildActionButton(
                        'Load Data',
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
                          print('encodedBibRecords: $encodedBibRecords');
                          print('encodedFinishTimes: $encodedFinishTimes');
                          if (encodedBibRecords == null || encodedFinishTimes == null) return;
                          
                          var runnerRecords = await processEncodedBibRecordsData(encodedBibRecords, context, raceId);
                          print('runnerRecords: $runnerRecords');
                          final timingData = await processEncodedTimingData(encodedFinishTimes, context);
                          print('timingData: $timingData');
                          
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
                        showArrow: false
                      )
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (race == null) {
      return Center(
        child: CircularProgressIndicator(), // Show loading indicator
      );
    }

    bool hasChanges = _name != race!.race_name || 
      _location != race!.location || 
      _date != race!.race_date.toString() || 
      _distance != race!.distance;

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 10.0),
              child: _buildContent(),
            ),
          ),
        ),
        if (hasChanges) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.updateRace({
                  'race_id': race?.race_id,
                  'race_name': _name,
                  'location': _location,
                  'race_date': _date,
                  'distance': _distance,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Changes saved successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ],
    );
  }
}