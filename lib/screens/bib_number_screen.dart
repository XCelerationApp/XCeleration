import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
// import '../models/race.dart';
import '../models/bib_data.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import '../utils/button_utils.dart';
import '../utils/time_formatter.dart';
import '../device_connection_popup.dart';
import '../device_connection_service.dart';
import '../database_helper.dart';
import '../runner_time_functions.dart';
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

  @override
  void initState() {
    super.initState();
    // race = widget.race!;
  }

  // Simplified bib number management
  Future<void> _handleBibNumber(String bibNumber, {
    List<double>? confidences,
    bool focus = false,
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

  Future<void> _validateBibNumber(int index, String bibNumber, List<double>? confidences) async {
    final provider = Provider.of<BibRecordsProvider>(context, listen: false);
    final record = provider.bibRecords[index];

    // Check confidence scores
    if (confidences?.any((score) => score < 0.9) ?? false) {
      record.flags['low_confidence_score'] = true;
    }

    // Check database
    final runner = await DatabaseHelper.instance.getRaceRunnerByBib(1, bibNumber, getTeamRunner: true);
    if (runner[0] == null) {
      record.flags['not_in_database'] = true;
    } else {
      record.name = runner[0]['name'];
      record.school = runner[0]['school'];
      record.flags['not_in_database'] = false;
    }

    // Check duplicates
    record.flags['duplicate_bib_number'] = provider.bibRecords
        .where((r) => r.bibNumber == bibNumber)
        .length > 1;

    setState(() {});
  }

  // Simplified QR code handling
  Future<void> _handleQRScan() async {
    await _cleanEmptyRecords();
    
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        await _processRaceData(result.rawContent);
      }
    } on MissingPluginException {
      await _handleScannerError();
    } catch (e) {
      DialogUtils.showErrorDialog(context, message: 'Failed to scan QR code: $e');
    }
  }

  Future<void> _cleanEmptyRecords() async {
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
    }
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
          await _handleBibNumber('', focus: true);
          provider.focusNodes.last.requestFocus();
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
    );
  }

  void _handleMainAction() {
    if (_isRaceFinished) {
      print('Race is finished');
      showDeviceConnectionPopup(
        context,
        deviceType: DeviceType.bibNumberDevice,
        backUpShareFunction: _handleQRScan,
        onDatatransferComplete: _processRaceData,
      );
    } else {
      _handleBibNumber('', focus: true);
    }
  }

  void _toggleRaceStatus() {
    setState(() {
      _isRaceFinished = !_isRaceFinished;
    });
  }

  _decodeRaceTimesString(String qrData) async {
    final decodedData = json.decode(qrData);
    final startTime = null;
    final endTime = loadDurationFromString(decodedData[1]);
    final condensedRecords = decodedData[0];
    List<Map<String, dynamic>> records = [];
    int place = 0;
    for (var recordString in condensedRecords) {
      if (loadDurationFromString(recordString) != null) {
        place++;
        records.add({'finish_time': recordString, 'type': 'runner_time', 'is_confirmed': false, 'text_color': null, 'place': place});
      }
      else {
        final [type, offBy, finish_time] = recordString.split(' ');
        if (type == 'confirm_runner_number'){
          records = confirmRunnerNumber(records, place - 1, finish_time);
        }
        else if (type == 'missing_runner_time'){
          records = await missingRunnerTime(int.tryParse(offBy), records, place, finish_time);
          place += int.tryParse(offBy)!;
        }
        else if (type == 'extra_runner_time'){
          records = await extraRunnerTime(int.tryParse(offBy), records, place, finish_time);
          place -= int.tryParse(offBy)!;
        }
        else {
          print("Unknown type: $type, string: $recordString");
        }
      }
    }
    return {'endTime': endTime, 'records': records, 'startTime': startTime};
  }

  Future<void> _processRaceData(String data) async {
    try {
      final timingData = await _decodeRaceTimesString(data);
      print(timingData);
      for (var record in timingData['records']) {
        print(record);
      }
      if (_isValidTimingData(timingData)) {
        // _navigateToRaceScreen(timingData);
      } else {
        DialogUtils.showErrorDialog(context, message: 'Error: Invalid QR code data');
      }
    } catch (e) {
      DialogUtils.showErrorDialog(context, message: 'Error processing data: $e');
      rethrow;
    }
  }

  bool _isValidTimingData(Map<String, dynamic> data) {
    return data.isNotEmpty &&
           data.containsKey('records') &&
           data.containsKey('endTime') &&
           data['records'].isNotEmpty &&
           data['endTime'] != null;
  }

  // void _navigateToRaceScreen(Map<String, dynamic> timingData) {
  //   final provider = Provider.of<BibRecordsProvider>(context, listen: false);
  //   timingData['bibs'] = provider.bibRecords.map((bib) => bib.bibNumber).toList();
    
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => RaceScreen(
  //         race: race,
  //         initialTabIndex: 1,
  //         timingData: timingData,
  //       ),
  //     ),
  //   );
  // }

  Future<void> _handleScannerError() async {
    DialogUtils.showErrorDialog(
      context,
      message: 'The QR code scanner is not available on this device.'
    );
    // Provide test data for development
    await _processRaceData(jsonEncode([
      [
        "0.75","1.40","2.83",
        "confirm_runner_number null 3.73",
        "4.65","6.95",
        "extra_runner_time 1 14.85",
        "17.75",
        "confirm_runner_number null 18.70"
      ],
      "21.61"
    ]));
  }

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
              buildRoleBar(context, 'bib recorder', 'Record Bib #s'),
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




// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:race_timing_app/screens/race_screen.dart';
// import 'package:race_timing_app/utils/time_formatter.dart';
// import 'dart:convert';
// import '../database_helper.dart';
// import 'package:barcode_scan2/barcode_scan2.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../models/race.dart';
// import '../constants.dart';
// import '../models/bib_data.dart';
// import '../device_connection_popup.dart';
// import '../device_connection_service.dart';
// import 'package:race_timing_app/runner_time_functions.dart';
// import 'package:race_timing_app/utils/dialog_utils.dart';
// import 'package:race_timing_app/utils/button_utils.dart';

// class BibNumberScreen extends StatefulWidget {
//   final Race race;
//   const BibNumberScreen({super.key, required this.race});

//   @override
//   State<BibNumberScreen> createState() => _BibNumberScreenState();
// }
// enum ConnectionStatus { connected, searching, finished, error, receiving }

// class _BibNumberScreenState extends State<BibNumberScreen> {
//   late int raceId;
//   late Race race;
//   bool _isRaceFinished = false;

//   @override
//   void initState() {
//     super.initState();
//     race = widget.race;
//     raceId = race.race_id;
//   }

//   Future<void> _addBibNumber([String bibNumber = '', List<double>? confidences = const [], bool focus = false, XFile? image]) async {
//     final index = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords.length;
//     setState(() {
//       Provider.of<BibRecordsProvider>(context, listen: false).addBibRecord({
//         'bib_number': bibNumber,
//         'confidences': confidences,
//         'image': image,
//         'name': '',
//         'school': '',
//         'flags': {
//           'duplicate_bib_number': false,
//           'not_in_database': false,
//           'low_confidence_score': false
//           }, // Initialize flags as an empty list
//       });
//       if (index > 0) {
//         Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index - 1].requestFocus();
//       }
//       if (focus) {
//         Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index].requestFocus();
//       }
//     });

//     if (bibNumber.isNotEmpty) {
//       if (confidences != null && confidences.isNotEmpty) {
//         if (confidences.any((confidence) => confidence < 0.9)) {
//           setState(() {
//             Provider.of<BibRecordsProvider>(context, listen: false).bibRecords[index]['flags']['low_confidence_score'] = true;
//           });
//         }
//       }
//       flagBibNumber(index, bibNumber);  
//     }
//   }

//   void flagBibNumber(int index, String bibNumber) async {
//     final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;
//     final runner = await DatabaseHelper.instance.getRaceRunnerByBib(1, bibNumber, getTeamRunner: true);
//       if (runner[0] == null) {
//         setState(() {
//           bibRecords[index]['flags']['not_in_database'] = true;
//         });
//       }
//       else {
//         setState(() {
//           bibRecords[index]['name'] = runner[0]['name'];
//           bibRecords[index]['school'] = runner[0]['school'];
//            bibRecords[index]['flags']['not_in_database'] = false;
//         });
//       }
//       bibRecords[index]['flags']['duplicate_bib_number'] = false;
//       for (int i = 0; i < bibRecords.length; i++) {
//         if (i != index && bibRecords[i]['bib_number'] == bibNumber) {
//           bibRecords[index]['flags']['duplicate_bib_number'] = true;
//         }
//       }
//   }
    
//   void _updateBibNumber(int index, String bibNumber) async {
//     final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;

//     setState(() {
//       bibRecords[index]['bib_number'] = bibNumber;
//     });
//     if (bibNumber.isNotEmpty) {
//       flagBibNumber(index, bibNumber);
//     } else {
//       setState(() {
//         bibRecords[index]['flags'] = {
//           'duplicate_bib_number': false,
//           'not_in_database': false,
//           'low_confidence_score': false
//           };
//       });
//     }
//   }

//   // void _captureBibNumbersWithCamera() async {
//   //   Navigator.push(
//   //     context,
//   //     MaterialPageRoute(
//   //       builder: (context) => CameraPage(
//   //         onDigitsDetected: (digits, confidences, image) {
//   //           if (digits != null) {
//   //             _addBibNumber(digits, confidences, image);
//   //           }
//   //         },
//   //       ),
//   //     ),
//   //   );
//   // }

//   void _confirmDeleteBibNumber(int index) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Confirm Deletion'),
//           content: Text('Are you sure you want to delete this bib number?'),
//           actions: [
//             TextButton(
//               child: Text('Cancel'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             TextButton(
//               child: Text('Delete'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _deleteBibNumber(index);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Future<void> _deleteBibNumber(int index) async {
//     setState(() {
//       Provider.of<BibRecordsProvider>(context, listen: false).removeBibRecord(index);
//     });
//   }

//   Future<void> _scanQRCode() async {
//     final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;

//     final emptyBibNumbers = bibRecords.where((bib) => bib['bib_number'] == null || bib['bib_number'].isEmpty).toList();
//     if (emptyBibNumbers.isNotEmpty) {
//       final confirmed = await showDialog<bool>(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             title: Text('Confirm Deletion'),
//             content: Text('There are ${emptyBibNumbers.length} empty bib numbers. They will be deleted if you continue. Are you sure you want to proceed?'),
//             actions: [
//               TextButton(
//                 child: Text('Cancel'),
//                 onPressed: () => Navigator.of(context).pop(false),
//               ),
//               TextButton(
//                 child: Text('Continue'),
//                 onPressed: () => Navigator.of(context).pop(true),
//               ),
//             ],
//           );
//         },
//       );
//       if (confirmed == false) {
//         return;
//       }
//       setState(() {
//         bibRecords.removeWhere((bib) => emptyBibNumbers.contains(bib));
//       });
//     }

//     try {
//       final result = await BarcodeScanner.scan();
//       if (result.type == ResultType.Barcode) {
//         print('Scanned barcode: ${result.rawContent}');
//         await _loadRaceTimesThroughString(result.rawContent);
//       }
//     } catch (e) {
//       if (e is MissingPluginException) {
//         DialogUtils.showErrorDialog(context, message: 'The QR code scanner is not available on this device.');
//         await _loadRaceTimesThroughString(jsonEncode([["0.75","1.40","2.83","confirm_runner_number null 3.73","4.65","6.95","extra_runner_time 1 14.85","17.75","confirm_runner_number null 18.70"],"21.61"]));
//       }
//       else {
//         DialogUtils.showErrorDialog(context, message: 'Failed to scan QR code: $e');
//       }
//     }
//   }

  // Future<Map<String, dynamic>> _decodeRaceTimesString(String qrData) async {
  //   final decodedData = json.decode(qrData);
  //   final startTime = null;
  //   final endTime = loadDurationFromString(decodedData[1]);
  //   final condensedRecords = decodedData[0];
  //   List<Map<String, dynamic>> records = [];
  //   int place = 0;
  //   for (var recordString in condensedRecords) {
  //     if (loadDurationFromString(recordString) != null) {
  //       place++;
  //       records.add({'finish_time': recordString, 'is_runner': true, 'is_confirmed': false, 'text_color': null, 'place': place});
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

//   Future<void> _loadRaceTimesThroughString(String qrData) async {
//     final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;
//     try {
//       final Map<String, dynamic> timingData = await _decodeRaceTimesString(qrData);
//       print('decoded timingData: $timingData');
//       for (var record in timingData['records']){
//         print(record['place']);
//       }
//       for (var record in timingData['records']){
//         print(record);
//       }

//       if (timingData.isNotEmpty && timingData.containsKey('records') && timingData.containsKey('endTime') && timingData['records'].isNotEmpty && timingData['endTime'] != null) {
//         timingData['bibs'] = bibRecords.map((bib) => bib['bib_number']).toList();
        
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => RaceScreen(race: race, initialTabIndex: 1, timingData: timingData),
//           ),
//         );
//       } else {
//         DialogUtils.showErrorDialog(context, message: 'Error: QR code data is invalid');
//       }
//     } catch (e) {
//       DialogUtils.showErrorDialog(context, message: 'Error: Failed to process QR code data $e');
//       rethrow;
//     }
//   }

//   void _raceFinished() {
//     setState(() {
//       _isRaceFinished = true;
//     });
//   }

//   void _restartRace() {
//     setState(() {
//       _isRaceFinished = false;
//     });
//   }


//   @override
//   void dispose() {
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;
//     final controllers = Provider.of<BibRecordsProvider>(context, listen: false).controllers;
//     final focusNodes = Provider.of<BibRecordsProvider>(context, listen: false).focusNodes;
//     return GestureDetector(
//     onTap: () {
//       FocusScope.of(context).unfocus(); // Dismiss the keyboard
//     },
//     child: Scaffold(
//       // appBar: AppBar(title: const Text('Record Bib Numbers')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Expanded(
//                child: ListView.builder(
//                 itemCount: bibRecords.length + 1,
//                 itemBuilder: (context, index) {
//                   final controller = (index < bibRecords.length) ? controllers[index] : null;
//                   final focusNode = (index < bibRecords.length) ? focusNodes[index] : null;

//                   final errorText = (index < bibRecords.length) ? '${bibRecords[index]['flags']['duplicate_bib_number'] ? 'Duplicate Bib Number\n' : '' }'
//                     '${bibRecords[index]['flags']['not_in_database'] ? 'Not in Database\n' : ''}'
//                     '${bibRecords[index]['flags']['low_confidence_score'] ? 'Low Confidence Score' : ''}' : '';

//                   return
//                     (index < bibRecords.length)
//                     ? Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
//                     child: Card(
//                       elevation: 2,
//                       margin: const EdgeInsets.symmetric(vertical: 6.0),
//                       color: bibRecords[index]['flags']['duplicate_bib_number'] ? Colors.red[50] :
//                              (bibRecords[index]['flags']['not_in_database'] || bibRecords[index]['flags']['low_confidence_score']) ? Colors.orange[50] :
//                              null,
//                       child: Padding(
//                         padding: const EdgeInsets.all(12.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               children: [
//                                 SizedBox(
//                                   width: 100,
//                                   child: TextField(
//                                     focusNode: focusNode,
//                                     controller: controller,
//                                     keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
//                                     textInputAction: TextInputAction.done,
//                                     decoration: InputDecoration(
//                                       hintText: 'Enter Bib',
//                                       border: OutlineInputBorder(),
//                                       hintStyle: const TextStyle(fontSize: 15),
//                                     ),
//                                     onSubmitted: (value) async { 
//                                       await _addBibNumber('', [], true);
//                                       focusNodes.last.requestFocus(); // Focus the last input box
//                                     },
//                                     onChanged: (value) => _updateBibNumber(index, value),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 8),

//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       if(bibRecords[index]['flags']['not_in_database'] == false && bibRecords[index]['bib_number'].isNotEmpty) ...[
//                                         Text('${bibRecords[index]['name']}, ${bibRecords[index]['school']}'),
//                                       ],
//                                     ],
//                                   ),
//                                 ),

//                                 const SizedBox(width: 8),
//                                 IconButton(
//                                   icon: const Icon(Icons.delete),
//                                   onPressed: () => _confirmDeleteBibNumber(index),
//                                 ),
//                               ],
//                             ),
//                             if (errorText.isNotEmpty) ...[
//                               if (bibRecords[index]['flags']['not_in_database'] == false) ...[
//                                 const SizedBox(height: 4),
//                                 Container(
//                                   width: double.infinity,
//                                   height: 1,
//                                   color: Colors.grey,
//                                 ),
//                                 const SizedBox(height: 4),
//                               ],
//                               Text(errorText),
//                             ],
//                           ],
//                         ),
//                       ),
//                     ),
//                   )
//                   :
//                   Row(
//                     children: [
//                       Padding(
//                       padding: const EdgeInsets.only(bottom: 16.0, top: 16.0, left: 5.0, right: 5.0),
//                       child: RoundedRectangleButton(
//                         text: _isRaceFinished ? 'Load Race Times' : 'Add Bib Number',
//                         color: AppColors.navBarColor,
//                         width: 175,
//                         height: 50,
//                         fontSize: 18,
//                         onPressed: () => {
//                           if (_isRaceFinished) {
//                             showDeviceConnectionPopup(context, deviceType: DeviceType.bibNumberDevice, backUpShareFunction: _scanQRCode, onDatatransferComplete: (String result) => _loadRaceTimesThroughString(result)),
//                           } else {
//                             _addBibNumber('', [], true)
//                           }
//                         },
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 16.0, top: 16.0, left: 5.0, right: 0.0),
//                       child: RoundedRectangleButton(
//                         text: _isRaceFinished ? 'Continue' : 'Finished',
//                         color: AppColors.primaryColor,
//                         width: 100,
//                         height: 50,
//                         fontSize: 18,
//                         onPressed: _isRaceFinished ? _restartRace : _raceFinished,
//                       ),
//                     )
//                   ]
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//     );
//   }
// }
