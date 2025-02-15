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
  // List<dynamic> _runners = [{'bib_number': '1234', 'name': 'Teo Donnelley', 'school': 'AW', 'grade': '11'}];
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleBibNumber('');
    });
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
                      final data = otherDevices[DeviceName.coach]?['data'];
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
                      print(otherDevices);
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

    // Validate all bib numbers to update duplicate states
    for (var i = 0; i < provider.bibRecords.length; i++) {
      await _validateBibNumber(i, provider.bibRecords[i].bibNumber, 
        i == index ? confidences : null);
    }

    Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index].requestFocus();
  }

  dynamic getRunnerByBib(String bibNumber) {
    try {
      return _runners.firstWhere(
        (runner) => runner['bib_number'] == bibNumber,
        orElse: () => null,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _validateBibNumber(int index, String bibNumber, List<double>? confidences) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final record = provider.bibRecords[index];

    // Reset all flags first
    record.flags['low_confidence_score'] = false;
    record.flags['not_in_database'] = false;
    record.flags['duplicate_bib_number'] = false;
    record.name = '';
    record.school = '';

    // If bibNumber is empty, clear all flags and return
    if (bibNumber.isEmpty) {
      setState(() {});
      return;
    }

    // Check confidence scores
    if (confidences?.any((score) => score < 0.9) ?? false) {
      record.flags['low_confidence_score'] = true;
    }

    // Check database
    final runner = getRunnerByBib(bibNumber);
    if (runner == null) {
      record.flags['not_in_database'] = true;
    } else {
      record.name = runner['name'];
      record.school = runner['school'];
      record.flags['not_in_database'] = false;
    }

    // Check duplicates
    final duplicateIndexes = provider.bibRecords
        .asMap()
        .entries
        .where((e) => e.value.bibNumber == bibNumber && e.value.bibNumber.isNotEmpty)
        .map((e) => e.key)
        .toList();

    if (duplicateIndexes.length > 1) {
      // Mark as duplicate if this is not the first occurrence
      record.flags['duplicate_bib_number'] = duplicateIndexes.indexOf(index) > 0;
    }

    setState(() {});
  }

  void _onBibRecordRemoved(int index) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    provider.removeBibRecord(index);

    // Revalidate all remaining bib numbers to update duplicate flags
    for (var i = 0; i < provider.bibRecords.length; i++) {
      _validateBibNumber(i, provider.bibRecords[i].bibNumber, null);
    }
  }

  // UI Components
  Widget _buildBibInput(int index, BibRecord record) {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  child: _buildBibTextField(index, provider),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (record.name.isNotEmpty && !record.hasErrors)
                        _buildRunnerInfo(record)
                      else if (record.hasErrors)
                        _buildErrorText(record),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildBibTextField(int index, BibRecordsProvider provider) {
    return TextField(
      focusNode: provider.focusNodes[index],
      controller: provider.controllers[index],
      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
      textInputAction: TextInputAction.done,
      style: const TextStyle(fontSize: 16),
      textAlign: TextAlign.start,
      decoration: const InputDecoration(
        hintText: 'Ex: 123',
        hintStyle: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      onSubmitted: (_) async {
        Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index].requestFocus();
        await _handleBibNumber('');
      },
      onChanged: (value) => _handleBibNumber(value, index: index),
    );
  }

  Widget _buildRunnerInfo(BibRecord record) {
    if (record.flags['not_in_database'] == false && record.bibNumber.isNotEmpty) {
      return Text(
        '${record.name}, ${record.school}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildErrorText(BibRecord record) {
    final errors = <String>[];
    if (record.flags['duplicate_bib_number']!) errors.add('Duplicate Bib Number');
    if (record.flags['not_in_database']!) errors.add('Runner not found');
    if (record.flags['low_confidence_score']!) errors.add('Low Confidence Score');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 16, color: Colors.red),
        const SizedBox(width: 8),
        Text(
          errors.join(' • '),
          style: const TextStyle(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: InkWell(
          onTap: () => _handleBibNumber(''),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.add_circle_outline,
              size: 32,
              color: AppColors.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    final hasNonEmptyBibNumbers = bibRecordsProvider.bibRecords.any((record) => record.bibNumber.isNotEmpty);

    if (!hasNonEmptyBibNumbers) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RoundedRectangleButton(
        text: 'Share Bib Numbers',
        color: AppColors.navBarColor,
        width: double.infinity,
        height: 50,
        fontSize: 18,
        onPressed: _showShareBibNumbersPopup,
      ),
    );
  }

  String _getEncodedBibData() {
    final bibRecordsProvider = Provider.of<BibRecordsProvider>(context, listen: false);
    return bibRecordsProvider.bibRecords.map((record) => record.bibNumber).toList().join(' ');
  }

  void _showShareBibNumbersPopup() async {
    final confirmed = await _cleanEmptyRecords();
    if (!confirmed) return;
    final String bibData = _getEncodedBibData();
    showDeviceConnectionPopup(
      context,
      deviceType: DeviceType.advertiserDevice,
      deviceName: DeviceName.bibRecorder,
      otherDevices: createOtherDeviceList(
        DeviceName.bibRecorder,
        DeviceType.advertiserDevice,
        data: bibData,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Column(
          children: [
            buildRoleBar(context, 'bib recorder', 'Record Bibs'),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<BibRecordsProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: provider.bibRecords.length + 1,
                    itemBuilder: (context, index) {
                      if (index < provider.bibRecords.length) {
                        return Dismissible(
                          key: ValueKey(provider.bibRecords[index]),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16.0),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            return await DialogUtils.showConfirmationDialog(
                              context,
                              title: 'Confirm Deletion',
                              content: 'Are you sure you want to delete this bib number?',
                            );
                          },
                          onDismissed: (direction) {
                            setState(() {
                              _onBibRecordRemoved(index);
                            });
                          },
                          child: _buildBibInput(
                            index,
                            provider.bibRecords[index],
                          ),
                        );
                      }
                      return _buildAddButton();
                    },
                  );
                },
              ),
            ),
            _buildBottomActionButtons(),
          ],
        ),
      ),
    );
  }
}
