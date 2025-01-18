import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'camera_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:race_timing_app/utils/time_formatter.dart';
import 'dart:convert';
import 'test_camera.dart';
import '../database_helper.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/timing_data.dart';
import 'edit_and_resolve_screen.dart';
import '../models/race.dart';
// import 'package:camera/camera.dart';

class BibNumberScreen extends StatefulWidget {
  final Race race;
  const BibNumberScreen({super.key, required this.race});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}


class _BibNumberScreenState extends State<BibNumberScreen> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  final List<Map<String, dynamic>> _bibRecords = [];
  // final ImagePicker _imagePicker = ImagePicker();
  // late CameraController _cameraController;
  // final app_bluetooth.BluetoothService _bluetoothService = app_bluetooth.BluetoothService();
  // BluetoothDevice? _connectedDevice;
  // List<BluetoothDevice> _availableDevices = [];
  late int raceId;
  late Race race;

  @override
  void initState() {
    super.initState();
    race = widget.race;
    raceId = race.race_id;
  }

  void _addBibNumber([String bibNumber = '', List<double>? confidences = const [], XFile? image]) async {
    final index = _bibRecords.length;
    setState(() {
      _controllers.add(TextEditingController(text: bibNumber));
      _focusNodes.add(FocusNode());
      _bibRecords.add({
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
    });

    if (bibNumber.isNotEmpty) {
      if (confidences != null && confidences.isNotEmpty) {
        if (confidences.any((confidence) => confidence < 0.9)) {
          setState(() {
            _bibRecords[index]['flags']['low_confidence_score'] = true;
          });
        }
      }
      flagBibNumber(index, bibNumber);  
    }
    else {
      // Automatically focus the last input box
      Future.delayed(Duration.zero, () {
        _focusNodes.last.requestFocus();
      });
    }
  }

  void flagBibNumber(int index, String bibNumber) async {
    final runner = await DatabaseHelper.instance.getRaceRunnerByBib(1, bibNumber, getShared: true);
      if (runner[0] == null) {
        setState(() {
          _bibRecords[index]['flags']['not_in_database'] = true;
        });
      }
      else {
        setState(() {
          _bibRecords[index]['name'] = runner[0]['name'];
          _bibRecords[index]['school'] = runner[0]['school'];
           _bibRecords[index]['flags']['not_in_database'] = false;
        });
      }
      _bibRecords[index]['flags']['duplicate_bib_number'] = false;
      for (int i = 0; i < _bibRecords.length; i++) {
        if (i != index && _bibRecords[i]['bib_number'] == bibNumber) {
          _bibRecords[index]['flags']['duplicate_bib_number'] = true;
        }
      }
  }
    
  void _updateBibNumber(int index, String bibNumber) async {
    setState(() {
      _bibRecords[index]['bib_number'] = bibNumber;
    });
    if (bibNumber.isNotEmpty) {
      flagBibNumber(index, bibNumber);
    } else {
      setState(() {
        _bibRecords[index]['flags'] = {
          'duplicate_bib_number': false,
          'not_in_database': false,
          'low_confidence_score': false
          };
      });
    }
  }

  void _captureBibNumbersWithCamera() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraPage(
          onDigitsDetected: (digits, confidences, image) {
            if (digits != null) {
              _addBibNumber(digits, confidences, image);
            }
          },
        ),
      ),
    );
  }
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
      _controllers.removeAt(index);
      _focusNodes.removeAt(index);
      _bibRecords.removeAt(index);
    }); 
    _flagBibNumberDuplicates(bibNumber, removeFlags: true);
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully resolved conflict')),
    );
  }

  void _showErrorMessage(String message, {String? title}) {
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title ?? 'Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the popup
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
  }

  void _scanQRCode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.type == ResultType.Barcode) {
        print('Scanned barcode: ${result.rawContent}');
        _processQRData(result.rawContent);
      }
    } catch (e) {
      if (e is MissingPluginException) {
        _showErrorMessage('The QR code scanner is not available on this device.');
        _processQRData(json.encode(['1', '2', '3', '4', '6', '5', '7', '8', '9', '10']));
      }
      else {
        _showErrorMessage('Failed to scan QR code: $e');
      }
    }
  }

  void _processQRData(String qrData) async {
    // final records = Provider.of<TimingData>(context, listen: false).records[raceId] ?? [];
    try {
      final Map<String, dynamic> timingData = json.decode(qrData);

      if (timingData.isNotEmpty && timingData.containsKey('records') && timingData.containsKey('startTime') && timingData.containsKey('endTime') && timingData['records'].isNotEmpty && timingData['startTime'] != null && timingData['endTime'] != null) {
        timingData['endTime'] = loadDurationFromString(timingData['endTime']);
        timingData['bibs'] = _bibRecords.map((bib) => bib['bib_number']).toList();
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EditAndResolveScreen(race: race, timingData: timingData)),
        );
      } else {
        _showErrorMessage('QR code data is invalid.');
      }
    } catch (e) {
      _showErrorMessage('Failed to process QR code data: $e');
    }
  }


  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Record Bib Numbers')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _bibRecords.length,
                itemBuilder: (context, index) {
                  // final record = _bibRecords[index];
                  final controller = _controllers[index];
                  final focusNode = _focusNodes[index];

                  final errorText = '${_bibRecords[index]['flags']['duplicate_bib_number'] ? 'Duplicate Bib Number\n' : '' }'
                    '${_bibRecords[index]['flags']['not_in_database'] ? 'Not in Database\n' : ''}'
                    '${_bibRecords[index]['flags']['low_confidence_score'] ? 'Low Confidence Score' : ''}';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      color: _bibRecords[index]['flags']['duplicate_bib_number'] ? Colors.red[50] :
                             (_bibRecords[index]['flags']['not_in_database'] || _bibRecords[index]['flags']['low_confidence_score']) ? Colors.orange[50] :
                             null,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    focusNode: focusNode,
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Enter Bib #',
                                      border: OutlineInputBorder(),
                                      helper: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if(_bibRecords[index]['flags']['not_in_database'] == false && _bibRecords[index]['bib_number'].isNotEmpty) ...[
                                            Text('${_bibRecords[index]['name']}, ${_bibRecords[index]['school']}'),
                                          ],
                                          if (errorText.isNotEmpty) ...[
                                            if (_bibRecords[index]['flags']['not_in_database'] == false) ...[
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
                                    onChanged: (value) => _updateBibNumber(index, value),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _confirmDeleteBibNumber(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_bibRecords.isNotEmpty)
              ElevatedButton(
                onPressed: _scanQRCode,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                ),
                child: const Text('Share Bib Numbers', style: TextStyle(fontSize: 20)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ElevatedButton.icon(
                onPressed: _captureBibNumbersWithCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Photo', style: TextStyle(fontSize: 20)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton(
                onPressed: _addBibNumber,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                ),
                child: const Text('Add Bib Number', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
