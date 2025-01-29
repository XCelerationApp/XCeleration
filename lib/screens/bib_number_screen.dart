import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:race_timing_app/screens/race_screen.dart';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'dart:convert';
import '../database_helper.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/race.dart';
import '../constants.dart';
import '../models/bib_data.dart';
import '../device_connection_popup.dart';
import '../device_connection_service.dart';
import 'package:race_timing_app/runner_time_functions.dart';

class BibNumberScreen extends StatefulWidget {
  final Race race;
  const BibNumberScreen({super.key, required this.race});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}
enum ConnectionStatus { connected, searching, finished, error, receiving }

class _BibNumberScreenState extends State<BibNumberScreen> {
  // final List<TextEditingController> _controllers = [];
  // final List<FocusNode> _focusNodes = [];
  // final List<Map<String, dynamic>> bibRecords = [];
  late int raceId;
  late Race race;
  bool _isRaceFinished = false;

  @override
  void initState() {
    super.initState();
    race = widget.race;
    raceId = race.race_id;
  }

  Future<void> _addBibNumber([String bibNumber = '', List<double>? confidences = const [], bool focus = false, XFile? image]) async {
    final index = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords.length;
    setState(() {
      // _controllers.add(TextEditingController(text: bibNumber));
      // _focusNodes.add(FocusNode());
      Provider.of<BibRecordsProvider>(context, listen: false).addBibRecord({
        'bib_number': bibNumber,
        'confidences': confidences,
        'image': image,
        'name': '',
        'school': '',
        'flags': {
          'duplicate_bib_number': false,
          'not_in_database': false,
          'low_confidence_score': false
          }, // Initialize flags as an empty list
      });
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index > 0) {
        Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index - 1].requestFocus();
      }
      if (focus) {
        Provider.of<BibRecordsProvider>(context, listen: false).focusNodes[index].requestFocus();
      }
      // });
    });

    if (bibNumber.isNotEmpty) {
      if (confidences != null && confidences.isNotEmpty) {
        if (confidences.any((confidence) => confidence < 0.9)) {
          setState(() {
            Provider.of<BibRecordsProvider>(context, listen: false).bibRecords[index]['flags']['low_confidence_score'] = true;
          });
        }
      }
      flagBibNumber(index, bibNumber);  
    }
    // else {
    //   // Automatically focus the last input box
    //   Future.delayed(Duration(milliseconds: 1000), () {
    //      WidgetsBinding.instance.addPostFrameCallback((_) {
    //       _focusNodes.last.requestFocus();
    //     });
    //   });
    // }
  }

  void flagBibNumber(int index, String bibNumber) async {
    final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;
    final runner = await DatabaseHelper.instance.getRaceRunnerByBib(1, bibNumber, getTeamRunner: true);
      if (runner[0] == null) {
        setState(() {
          bibRecords[index]['flags']['not_in_database'] = true;
        });
      }
      else {
        setState(() {
          bibRecords[index]['name'] = runner[0]['name'];
          bibRecords[index]['school'] = runner[0]['school'];
           bibRecords[index]['flags']['not_in_database'] = false;
        });
      }
      bibRecords[index]['flags']['duplicate_bib_number'] = false;
      for (int i = 0; i < bibRecords.length; i++) {
        if (i != index && bibRecords[i]['bib_number'] == bibNumber) {
          bibRecords[index]['flags']['duplicate_bib_number'] = true;
        }
      }
  }
    
  void _updateBibNumber(int index, String bibNumber) async {
    final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;

    setState(() {
      bibRecords[index]['bib_number'] = bibNumber;
    });
    if (bibNumber.isNotEmpty) {
      flagBibNumber(index, bibNumber);
    } else {
      setState(() {
        bibRecords[index]['flags'] = {
          'duplicate_bib_number': false,
          'not_in_database': false,
          'low_confidence_score': false
          };
      });
    }
  }

  // void _captureBibNumbersWithCamera() async {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => CameraPage(
  //         onDigitsDetected: (digits, confidences, image) {
  //           if (digits != null) {
  //             _addBibNumber(digits, confidences, image);
  //           }
  //         },
  //       ),
  //     ),
  //   );
  // }

  void _confirmDeleteBibNumber(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this bib number?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _deleteBibNumber(index); // Proceed with deletion
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBibNumber(int index) async {
    setState(() {
      Provider.of<BibRecordsProvider>(context, listen: false).removeBibRecord(index);
    });
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.red[900], fontSize: 16)),
        backgroundColor: Colors.white,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _scanQRCode() async {
    final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;

    final emptyBibNumbers = bibRecords.where((bib) => bib['bib_number'] == null || bib['bib_number'].isEmpty).toList();
    if (emptyBibNumbers.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Confirm Deletion'),
            content: Text('There are ${emptyBibNumbers.length} empty bib numbers. They will be deleted if you continue. Are you sure you want to proceed?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('Continue'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );
      if (confirmed == false) {
        return;
      }
      setState(() {
        bibRecords.removeWhere((bib) => emptyBibNumbers.contains(bib));
      });
    }

    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        print('Scanned barcode: ${result.rawContent}');
        await _loadRaceTimesThroughString(result.rawContent);
      }
    } catch (e) {
      if (e is MissingPluginException) {
        _showErrorMessage('The QR code scanner is not available on this device.');
        await _loadRaceTimesThroughString(jsonEncode([["0.75","1.40","2.83","confirm_runner_number null 3.73","4.65","6.95","extra_runner_time 1 14.85","17.75","confirm_runner_number null 18.70"],"21.61"]));
      }
      else {
        _showErrorMessage('Failed to scan QR code: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _decodeRaceTimesString(String qrData) async {
    final decodedData = json.decode(qrData);
    final startTime = null;
    final endTime = loadDurationFromString(decodedData[1]);
    final condensedRecords = decodedData[0];
    List<Map<String, dynamic>> records = [];
    int place = 0;
    for (var recordString in condensedRecords) {
      if (loadDurationFromString(recordString) != null) {
        place++;
        records.add({'finish_time': recordString, 'is_runner': true, 'is_confirmed': false, 'text_color': null, 'place': place});
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

  Future<void> _loadRaceTimesThroughString(String qrData) async {
    final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    try {
      final Map<String, dynamic> timingData = await _decodeRaceTimesString(qrData);
      print('decoded timingData: $timingData');
      for (var record in timingData['records']){
        print(record['place']);
      }
      for (var record in timingData['records']){
        print(record);
      }

      if (timingData.isNotEmpty && timingData.containsKey('records') && timingData.containsKey('endTime') && timingData['records'].isNotEmpty && timingData['endTime'] != null) {
        // timingData['endTime'] = loadDurationFromString(timingData['endTime']);
        timingData['bibs'] = bibRecords.map((bib) => bib['bib_number']).toList();
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RaceScreen(race: race, initialTabIndex: 1, timingData: timingData),
          ),
        );
      } else {
        _showErrorMessage('Error: QR code data is invalid');
      }
    } catch (e) {
      _showErrorMessage('Error: Failed to process QR code data $e');
      rethrow;
    }
  }

  void _raceFinished() {
    setState(() {
      _isRaceFinished = true;
    });
    // Implement race finished logic here
  }

  void _restartRace() {
    setState(() {
      _isRaceFinished = false;
    });
  }


  @override
  void dispose() {
    // for (var controller in _controllers) {
    //   controller.dispose();
    // }
    // for (var focusNode in _focusNodes) {
    //   focusNode.dispose();
    // }
    // Provider.of<BibRecordsProvider>(context, listen: false).clearBibRecords();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bibRecords = Provider.of<BibRecordsProvider>(context, listen: false).bibRecords;
    final controllers = Provider.of<BibRecordsProvider>(context, listen: false).controllers;
    final focusNodes = Provider.of<BibRecordsProvider>(context, listen: false).focusNodes;
    return GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus(); // Dismiss the keyboard
    },
    child: Scaffold(
      // appBar: AppBar(title: const Text('Record Bib Numbers')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: bibRecords.length,
                itemBuilder: (context, index) {
                  // final record = bibRecords[index];
                  final controller = controllers[index];
                  final focusNode = focusNodes[index];

                  final errorText = '${bibRecords[index]['flags']['duplicate_bib_number'] ? 'Duplicate Bib Number\n' : '' }'
                    '${bibRecords[index]['flags']['not_in_database'] ? 'Not in Database\n' : ''}'
                    '${bibRecords[index]['flags']['low_confidence_score'] ? 'Low Confidence Score' : ''}';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      color: bibRecords[index]['flags']['duplicate_bib_number'] ? Colors.red[50] :
                             (bibRecords[index]['flags']['not_in_database'] || bibRecords[index]['flags']['low_confidence_score']) ? Colors.orange[50] :
                             null,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    focusNode: focusNode,
                                    controller: controller,
                                    keyboardType: TextInputType.numberWithOptions(signed: true, decimal: false),
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      hintText: 'Enter Bib',
                                      border: OutlineInputBorder(),
                                      hintStyle: const TextStyle(fontSize: 15),
                                      // helper: Column(
                                      //   crossAxisAlignment: CrossAxisAlignment.start,
                                      //   children: [
                                      //     if(bibRecords[index]['flags']['not_in_database'] == false && bibRecords[index]['bib_number'].isNotEmpty) ...[
                                      //       Text('${bibRecords[index]['name']}, ${bibRecords[index]['school']}'),
                                      //     ],
                                      //     if (errorText.isNotEmpty) ...[
                                      //       if (bibRecords[index]['flags']['not_in_database'] == false) ...[
                                      //         const SizedBox(height: 4),
                                      //         Container(
                                      //           width: double.infinity,
                                      //           height: 1,
                                      //           color: Colors.grey,
                                      //         ),
                                      //         const SizedBox(height: 4),
                                      //       ],
                                      //       Text(errorText),
                                      //     ],
                                      //   ],
                                      // ),
                                    ),
                                    onSubmitted: (value) async { 
                                      await _addBibNumber('', [], true);
                                      // Future.delayed(Duration(milliseconds: 500), () {
                                      //   WidgetsBinding.instance.addPostFrameCallback((_) {
                                        focusNodes.last.requestFocus(); // Focus the last input box
                                      //   });
                                      // });
                                    },
                                    onChanged: (value) => _updateBibNumber(index, value),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if(bibRecords[index]['flags']['not_in_database'] == false && bibRecords[index]['bib_number'].isNotEmpty) ...[
                                        Text('${bibRecords[index]['name']}, ${bibRecords[index]['school']}'),
                                      ],
                                      // if (errorText.isNotEmpty) ...[
                                      //   if (bibRecords[index]['flags']['not_in_database'] == false) ...[
                                      //     const SizedBox(height: 4),
                                      //     Container(
                                      //       width: double.infinity,
                                      //       height: 1,
                                      //       color: Colors.grey,
                                      //     ),
                                      //     const SizedBox(height: 4),
                                      //   ],
                                      //   Text(errorText),
                                      // ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _confirmDeleteBibNumber(index),
                                ),
                              ],
                            ),
                            if (errorText.isNotEmpty) ...[
                              if (bibRecords[index]['flags']['not_in_database'] == false) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text(errorText),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (focusNodes.indexWhere((element) => FocusScope.of(context).hasFocus && element.hasFocus) == -1) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 16.0, left: 0.0, right: 5.0),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        color: AppColors.navBarColor, // Button color
                        border: Border.all(
                          // color: const Color.fromARGB(255, 60, 60, 60), // Inner darker border
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navBarColor, // Outer lighter border
                            spreadRadius: 2, // Width of the outer border
                          ),
                        ],
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: ElevatedButton(
                        onPressed: () => {
                          if (_isRaceFinished) {
                            showDeviceConnectionPopup(context, deviceType: DeviceType.bibNumberDevice, backUpShareFunction: _scanQRCode, onDatatransferComplete: (String result) => _loadRaceTimesThroughString(result)),
                          } else {
                            _addBibNumber('', [], true)
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          fixedSize: const Size(175, 50),
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                        ),
                        child: Text(_isRaceFinished ? 'Load Race Times' : 'Add Bib Number', style: TextStyle(fontSize: 18, color: Colors.white))
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 16.0, left: 5.0, right: 0.0),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        color: AppColors.primaryColor, // Button color
                        border: Border.all(
                          // color: const Color.fromARGB(255, 60, 60, 60), // Inner darker border
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor, // Outer lighter border
                            spreadRadius: 2, // Width of the outer border
                          ),
                        ],
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: ElevatedButton(
                        onPressed: _isRaceFinished ? _restartRace : _raceFinished,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          fixedSize: const Size(100, 50),
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                        ),
                        child: Text(_isRaceFinished ? 'Continue': 'Finished', style: const TextStyle(fontSize: 18.0, color: Colors.white))
                      ),
                    ),
                  ),
                ],    
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
