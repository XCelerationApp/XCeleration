import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
// import '../models/race.dart';
import '../models/bib_data.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../utils/button_utils.dart';
// import '../utils/time_formatter.dart';
import '../device_connection_popup.dart';
import '../device_connection_service.dart';
// import '../database_helper.dart';
// import '../runner_time_functions.dart';
// import 'race_screen.dart';
import '../role_functions.dart';

class BibNumberScreen extends StatefulWidget {
  // final Race? race;
  const BibNumberScreen({super.key});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  // late Race race;
  bool _isRaceFinished = false;
  // List<dynamic> _runners = [{'bib_number': '00000', 'name': 'Runner 1', 'school': 'School 1', 'grade': 'Grade 1'}];
  List<dynamic> _runners = [];
  Map<DeviceName, Map<String, dynamic>> otherDevices = createOtherDeviceList(
      DeviceName.bibRecorder,
      DeviceType.browserDevice,
    );

  @override
  void initState() {
    super.initState();
    // race = widget.race!;
    _checkForRunners();
  }

  void _checkForRunners() {
    if (_runners.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('No Runners Loaded'),
              content: const Text('There are no runners loaded in the system. Please load runners to continue.'),
              actions: [
                TextButton(
                  child: const Text('Return to Home'),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                TextButton(
                  child: const Text('Load Runners'),
                  onPressed: () async{
                    await showDeviceConnectionPopup(
                      context,
                      deviceType: DeviceType.browserDevice,
                      deviceName: DeviceName.bibRecorder,
                      otherDevices: otherDevices,
                    );
                    setState(() {
                      final data = otherDevices[DeviceName.bibRecorder]?['data'];
                      if (data != null) {
                        final runners = jsonDecode(data);
                        if (runners.runtimeType != List || runners.isEmpty) {
                          DialogUtils.showErrorDialog(context, 
                            message: 'Invalid data received from bib recorder. Please try again.');
                        }
                        final runnerInCorrectFormat = runners.every((runner) => runner.containsKey('bib_number') && runner.containsKey('name') && runner.containsKey('school') && runner.containsKey('grade'));
                        if (!runnerInCorrectFormat) {
                          DialogUtils.showErrorDialog(context, 
                            message: 'Invalid data received from bib recorder. Please try again.');
                        }

                        if (_runners.isNotEmpty) _runners.clear();
                        print('Runners loaded: $runners');
                        _runners = runners;
                      }
                    });
                    if (_runners.isNotEmpty) {
                      Navigator.pop(context);
                    }
                    else {
                      print('No runners loaded');
                    }
                  },
                ),
              ],
            );
          },
        );
      });
    }
  }

  // Simplified bib number management
  Future<void> _handleBibNumber(String bibNumber, {
    List<double>? confidences,
    int? index,
  }) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    
    if (index == null) {
      index = provider.bibRecords.length;
      provider.addBibRecord(BibRecord(
        bibNumber: bibNumber,
        confidences: confidences ?? [],
      ));
    } else {
      provider.updateBibRecord(index, bibNumber);
    }

    if (bibNumber.isNotEmpty) {
      await _validateBibNumber(index, bibNumber, confidences);
    }

    Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index].requestFocus();
  }

  dynamic getRunnerByBib(String bibNumber) {
    final runner = _runners.firstWhere((runner) => runner['bib_number'] == bibNumber);
    return runner;
  }

  Future<void> _validateBibNumber(int index, String bibNumber, List<double>? confidences) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final record = provider.bibRecords[index];

    // Check confidence scores
    if (confidences?.any((score) => score < 0.9) ?? false) {
      record.flags['low_confidence_score'] = true;
    }

    // Check database
    // final runner = await DatabaseHelper.instance.getRaceRunnerByBib(1, bibNumber, getTeamRunner: true);
    final runner = getRunnerByBib(bibNumber);
    if (runner == null) {
      record.flags['not_in_database'] = true;
    } else {
      record.name = runner['name'];
      record.school = runner['school'];
      record.flags['not_in_database'] = false;
    }

    // Check duplicates
    record.flags['duplicate_bib_number'] = provider.bibRecords
        .where((r) => r.bibNumber == bibNumber)
        .length > 1;

    setState(() {});
  }

  Future<bool> _cleanEmptyRecords() async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final emptyRecords = provider.bibRecords.where((bib) => bib.bibNumber.isEmpty).length;
    
    if (emptyRecords > 0) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Clean Empty Records',
        content: 'There are $emptyRecords empty bib numbers that will be deleted. Continue?',
      );
      
      if (confirmed) {
        setState(() {
          provider.bibRecords.removeWhere((bib) => bib.bibNumber.isEmpty);
        });
      }
      return confirmed;
    }
    return true;
  }

  // UI Components
  Widget _buildBibInput(int index, BibRecord record) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      color: _getBibCardColor(record),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildBibTextField(index, provider),
                const SizedBox(width: 8),
                _buildRunnerInfo(record),
                _buildDeleteButton(index),
              ],
            ),
            if (record.hasErrors) 
              _buildErrorText(record),
          ],
        ),
      ),
    );
  }

  Widget _buildBibTextField(int index, BibRecordsProvider provider) {
    return SizedBox(
      width: 100,
      child: TextField(
        focusNode: provider.focusNodes[index],
        controller: provider.controllers[index],
        keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: 'Enter Bib',
          border: OutlineInputBorder(),
          hintStyle: TextStyle(fontSize: 15),
        ),
        onSubmitted: (_) async {
          if (!_isRaceFinished) {
            Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index].requestFocus();
            await _handleBibNumber('');
          }
        },
        onChanged: (value) => _handleBibNumber(value, index: index),
      ),
    );
  }

  Widget _buildRunnerInfo(BibRecord record) {
    if (record.flags['not_in_database'] == false && record.bibNumber.isNotEmpty) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${record.name}, ${record.school}'),
          ],
        ),
      );
    }
    return const Spacer();
  }

  Widget _buildDeleteButton(int index) {
    return IconButton(
      icon: const Icon(Icons.delete),
      onPressed: () => _confirmDeleteBibNumber(index),
    );
  }

  Widget _buildErrorText(BibRecord record) {
    final errors = <String>[];
    if (record.flags['duplicate_bib_number']!) errors.add('Duplicate Bib Number');
    if (record.flags['not_in_database']!) errors.add('Runner not found');
    if (record.flags['low_confidence_score']!) errors.add('Low Confidence Score');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (record.flags['not_in_database'] == false) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.grey,
          ),
        ],
        const SizedBox(height: 4),
        Text(errors.join('\n')),
      ],
    );
  }

  Color? _getBibCardColor(BibRecord record) {
    if (record.flags['duplicate_bib_number']!) return Colors.red[50];
    if (record.flags['not_in_database']! || record.flags['low_confidence_score']!) {
      return Colors.orange[50];
    }
    return null;
  }

  Widget _buildActionButtons() {
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    final showToggleRaceStatusButton = bibRecordsProvider.bibRecords.isNotEmpty && bibRecordsProvider.bibRecords.firstWhere((record) => record.bibNumber.isNotEmpty, orElse: () => BibRecord(bibNumber: '')).bibNumber.isNotEmpty;
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 5.0),
          child: RoundedRectangleButton(
            text: _isRaceFinished ? 'Load Race Times' : 'Add Bib Number',
            color: AppColors.navBarColor,
            width: 175,
            height: 50,
            fontSize: 18,
            onPressed: _handleMainAction,
          ),
        ),
        if (showToggleRaceStatusButton) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(5.0, 16.0, 0.0, 16.0),
            child: RoundedRectangleButton(
              text: _isRaceFinished ? 'Continue' : 'Finished',
              color: AppColors.primaryColor,
              width: 100,
              height: 50,
              fontSize: 18,
              onPressed: _toggleRaceStatus,
            ),
          ),
        ],
      ],
    );
  }

  void _handleMainAction() {
    if (_isRaceFinished) {
      print('Race is finished');
      showDeviceConnectionPopup(
        context,
        deviceType: DeviceType.advertiserDevice,
        deviceName: DeviceName.bibRecorder,
        otherDevices: createOtherDeviceList(
          DeviceName.bibRecorder,
          DeviceType.advertiserDevice,
          data: '_bibRecords.encode()',
        ),
      );
    } else {
      _handleBibNumber('');

    }
  }

  /// Toggle [_isRaceFinished] and clean up empty records if race is finished.
  void _toggleRaceStatus() async {
    if (!_isRaceFinished) {
      final confirmed = await _cleanEmptyRecords();
      if (!confirmed) return;
    }
    setState(() {
      _isRaceFinished = !_isRaceFinished;
    });
  }

  // _decodeRaceTimesString(String qrData) async {
  //   final decodedData = json.decode(qrData);
  //   final startTime = null;
  //   final endTime = loadDurationFromString(decodedData[1]);
  //   final condensedRecords = decodedData[0];
  //   List<Map<String, dynamic>> records = [];
  //   int place = 0;
  //   for (var recordString in condensedRecords) {
  //     if (loadDurationFromString(recordString) != null) {
  //       place++;
  //       records.add({'finish_time': recordString, 'type': 'runner_time', 'is_confirmed': false, 'text_color': null, 'place': place});
  //     }
  //     else {
  //       final [type, offBy, finish_time] = recordString.split(' ');
  //       if (type == 'confirm_runner_number'){
  //         records = confirmRunnerNumber(records, place - 1, finish_time);
  //       }
  //       else if (type == 'missing_runner_time'){
  //         records = await missingRunnerTime(int.tryParse(offBy), records, place, finish_time);
  //         place += int.tryParse(offBy)!;
  //       }
  //       else if (type == 'extra_runner_time'){
  //         records = await extraRunnerTime(int.tryParse(offBy), records, place, finish_time);
  //         place -= int.tryParse(offBy)!;
  //       }
  //       else {
  //         print("Unknown type: $type, string: $recordString");
  //       }
  //     }
  //   }
  //   return {'endTime': endTime, 'records': records, 'startTime': startTime};
  // }

  // Future<void> _processRaceData(String data) async {
  //   try {
  //     final timingData = await _decodeRaceTimesString(data);
  //     print(timingData);
  //     for (var record in timingData['records']) {
  //       print(record);
  //     }
  //     if (_isValidTimingData(timingData)) {
  //       // _navigateToRaceScreen(timingData);
  //     } else {
  //       DialogUtils.showErrorDialog(context, message: 'Error: Invalid QR code data');
  //     }
  //   } catch (e) {
  //     DialogUtils.showErrorDialog(context, message: 'Error processing data: $e');
  //     rethrow;
  //   }
  // }

  // bool _isValidTimingData(Map<String, dynamic> data) {
  //   return data.isNotEmpty &&
  //          data.containsKey('records') &&
  //          data.containsKey('endTime') &&
  //          data['records'].isNotEmpty &&
  //          data['endTime'] != null;
  // }

  void _confirmDeleteBibNumber(int index) {
    DialogUtils.showConfirmationDialog(
      context,
      title: 'Confirm Deletion',
      content: 'Are you sure you want to delete this bib number?',
    ).then((confirmed) {
      if (confirmed) {
        setState(() {
          Provider.of<BibRecordsProvider>(context, listen: false)
            .removeBibRecord(index);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              buildRoleBar(context, 'bib recorder', 'Record Bibs'),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer<BibRecordsProvider>(
                  builder: (context, provider, _) {
                    return ListView.builder(
                      itemCount: provider.bibRecords.length + 1,
                      itemBuilder: (context, index) {
                        if (index < provider.bibRecords.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 8.0,
                            ),
                            child: _buildBibInput(
                              index,
                              provider.bibRecords[index],
                            ),
                          );
                        }
                        return _buildActionButtons();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
