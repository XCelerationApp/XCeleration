import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'camera_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'test_camera.dart';
import '../database_helper.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:race_timing_app/bluetooth_service.dart' as app_bluetooth;

class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key});

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
        });
      }
      _flagBibNumberDuplicates(bibNumber);
    }
    else {
      // Automatically focus the last input box
      Future.delayed(Duration.zero, () {
        _focusNodes.last.requestFocus();
      });
    }
  }

  void _flagBibNumberDuplicates(String bibNumber, {bool removeFlags = false}) {
    List duplicates = [];
    for (int i = 0; i < _bibRecords.length; i++) {
      if (_bibRecords[i]['bib_number'] == bibNumber) {
        duplicates.add(i);
      }
    }
    if (removeFlags) {
      if (duplicates.length == 1) {
        setState(() {
          _bibRecords[duplicates[0]]['flags']['duplicate_bib_number'] = false;
        });
      }
    }
    else {
      for (int i = 0; i < duplicates.length; i++) {
        if (duplicates.length >= 2) {
          setState(() {
            _bibRecords[duplicates[i]]['flags']['duplicate_bib_number'] = true;
          });
        }
      }
    }
  }
    
  void _updateBibNumber(int index, String bibNumber) async {
    final oldBibNumber = _bibRecords[index]['bib_number'];
    setState(() {
      _bibRecords[index]['bib_number'] = bibNumber;
    });
    _flagBibNumberDuplicates(oldBibNumber, removeFlags: true);
    if (bibNumber.isNotEmpty) {
      _bibRecords[index]['flags']['duplicate_bib_number'] = false;
      _flagBibNumberDuplicates(bibNumber);
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


  Future<void> _deleteBibNumber(int index) async {
    final bibNumber = _bibRecords[index]['bib_number'];
    setState(() {
      _controllers.removeAt(index);
      _focusNodes.removeAt(index);
      _bibRecords.removeAt(index);
    }); 
    _flagBibNumberDuplicates(bibNumber, removeFlags: true);
  }


  void _confirmAndShowQrCode() {
    int errorCount = _bibRecords.where((record) => 
      record['flags']['not_in_database'] || record['flags']['low_confidence_score'] || record['flags']['duplicate_bib_number']
    ).length;
    if (errorCount > 0) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Confirm Share'),
            content: Text('There ${errorCount == 1 ? 'is 1 bib with an error' : 'are $errorCount bibs with errors'}. Are you sure you want to share?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Share'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _showQrCode();
                },
              ),
            ],
          );
        },
      );
    }
    else {
      _showQrCode();
    }
  }
  void _showQrCode() {
    final data = _generateQrData(); // Ensure this returns a String
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Share Bib Numbers'),
          content: SizedBox(
            width: 200,
            height: 200,
            child: QrImageView(
              data: data,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M, // Adjust as needed
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _generateQrData() {
    return jsonEncode(_bibRecords.map((record) => record['bib_number']).toList());
  }

  // void _findDevices() async {
  //   try {
  //     // Check if Bluetooth is enabled
  //     final isOn = await _bluetoothService.isBluetoothOn();
  //     if (!isOn) {
  //       _showBluetoothOffDialog();
  //       return;
  //     }

  //     // Proceed to find devices if Bluetooth is on
  //     await for (final devices in _bluetoothService.getAvailableDevices()) {
  //       setState(() {
  //         _availableDevices = devices;
  //       });
  //     }
  //   } catch (e) {
  //     // Handle other exceptions (optional)
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to scan for devices: $e')),
  //     );
  //   }
  // }

  // void _disconnectDevice() async {
  //   final bluetoothService = app_bluetooth.BluetoothService();
  //   if (_connectedDevice == null) return;

  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Confirm Disconnect'),
  //         content: const Text('Are you sure you want to disconnect?'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () => Navigator.of(context).pop(false),
  //           ),
  //           TextButton(
  //             child: const Text('Disconnect'),
  //             onPressed: () => Navigator.of(context).pop(true),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   if (confirm == true) {
  //     try {
  //       await bluetoothService.disconnectDevice(_connectedDevice!);
  //       setState(() {
  //         _connectedDevice = null; // Clear the connected device
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Disconnected successfully')),
  //       );
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Failed to disconnect: $e')),
  //       );
  //     }
  //   }
  // }

  // void _connectToDevice(BluetoothDevice device) async {
  //   try {
  //     final connectedDevice = await _bluetoothService.connectToDevice(device);
  //     setState(() {
  //       _connectedDevice = connectedDevice;
  //     });
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Connected successfully')),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to connect: $e')),
  //     );
  //   }
  // }

  // void _sendBibNumbers() async {
  //   if (_connectedDevice == null) return;

  //   try {
  //     final data = _bibRecords.join(';').codeUnits; // Serialize the bib numbers
  //     await _bluetoothService.sendData(_connectedDevice!, data);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Bib numbers sent successfully')),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to send bib numbers: $e')),
  //     );
  //   }
  // }

  // void _showBluetoothOffDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Bluetooth Off'),
  //       content: const Text('Please turn on Bluetooth to search for devices.'),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //           },
  //           child: const Text('OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }


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
                                  onPressed: () => _deleteBibNumber(index),
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
                onPressed: _confirmAndShowQrCode,
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
            // ElevatedButton(
            //   onPressed: _findDevices,
            //   child: const Text('Find Devices'),
            // ),
            // if (_connectedDevice == null)
            //   DropdownButton<BluetoothDevice>(
            //     hint: const Text('Select Device'),
            //     items: _availableDevices.map((device) {
            //       return DropdownMenuItem(
            //         value: device,
            //         child: Text(device.platformName),
            //       );
            //     }).toList(),
            //     onChanged: (device) {
            //       if (device != null) _connectToDevice(device);
            //     },
            //   ),
            // if (_connectedDevice != null)
            //   ElevatedButton(
            //     onPressed: _sendBibNumbers,
            //     child: const Text('Send Bib Numbers'),
            //   ),
            // if (_connectedDevice != null) ...[
            //     const SizedBox(height: 8),
            //     ElevatedButton(
            //       onPressed: _disconnectDevice, // Add disconnect button
            //       child: const Text('Disconnect'),
            //     ),
            // ],
          ],
        ),
      ),
    );
  }
}
