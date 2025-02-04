import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'race_info_screen.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/race.dart';
import '../database_helper.dart';
// import 'race_detail_screen.dart';
// import 'race_info_screen.dart';
// import 'race_screen.dart';
import '../utils/app_colors.dart';
import '../utils/dialog_utils.dart';
import 'dart:io';
import '../role_functions.dart';
import '../utils/sheet_utils.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../device_connection_popup.dart';
import '../device_connection_service.dart';

class RacesScreen extends StatefulWidget {
  const RacesScreen({super.key});

  @override
  _RacesScreenState createState() => _RacesScreenState();
}


class _RacesScreenState extends State<RacesScreen> {
  List<Race> races = [];
  bool isLocationButtonVisible = true;
  final nameController = TextEditingController(text: 'Untitled Race');
  final locationController = TextEditingController(text: '');
  final dateController = TextEditingController(text: '');
  final distanceController = TextEditingController(text: '');
  final userlocationController = TextEditingController(text: '');
  final List<TextEditingController> _teamControllers = [TextEditingController(), TextEditingController()];
  final List<Color> _teamColors = [Colors.white, Colors.white];
  String unit = 'miles';
  
  @override
  void initState() {
    super.initState();
    _loadRaces();
  }
  
  Future<void> _loadRaces() async {
    final races = await DatabaseHelper.instance.getAllRaces();
    setState(() {
      this.races = races;
    });
  }

  void _updateLocationButtonVisibility() {
    setState(() {
      isLocationButtonVisible = locationController.text.trim() != userlocationController.text.trim();
      print('isLocationButtonVisible: $isLocationButtonVisible');
      print('locationController.text: ${locationController.text}');
      print('userlocationController.text: ${userlocationController.text}');
      print('locationController.text.trim(): ${locationController.text.trim()}');
      print('userlocationController.text.trim(): ${userlocationController.text.trim()}');
    });
  }

  // Method to add a new TextEditingController
  void _addTeamField() {
    setState(() {
      print('_addTeamField');
      _teamControllers.add(TextEditingController());
      _teamColors.add(Colors.white);
    });
  }

  void _showCreateRaceSheet(BuildContext context) {
    _resetControllers();

    showModalBottomSheet(
      backgroundColor: AppColors.backgroundColor,
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.92,
              child: _buildCreateRaceSheetContent(setState),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateRaceSheetContent(StateSetter setState) {
    return Column(
      children: [
        const SizedBox(height: 10),
        createSheetHandle(height: 10, width: 60),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCreateRaceSheetTitle(),
                _buildRaceNameField(),
                _buildCompetingTeamsField(setState),
                _buildRaceLocationField(),
                _buildRaceDateField(),
                _buildRaceDistanceField(),
                _buildCreateButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _resetControllers() {
    nameController.text = 'Untitled Race';
    locationController.text = '';
    dateController.text = '';
    distanceController.text = '';
    userlocationController.text = '';
    isLocationButtonVisible = true;
    _teamControllers.clear();
    _teamControllers.add(TextEditingController());
    _teamControllers.add(TextEditingController());
    _teamColors.clear();
    _teamColors.add(Colors.white);
    _teamColors.add(Colors.white);
  }

  Widget _buildRaceNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Race Name:',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              // labelText: 'Race Name',
              // border: OutlineInputBorder(),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          fixedSize: const Size(300, 75),
        ),
        onPressed: () {
          _createRace();
        },
        child: const Text('Create', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.backgroundColor)),
      ),
    );
  }

  Widget _buildCreateRaceSheetTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Create a New Race',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompetingTeamsField(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Competing Teams:',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ..._teamControllers.map((controller) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Team Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Pick a color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: _teamColors[_teamControllers.indexOf(controller)],
                            onColorChanged: (color) {
                              setState(() {
                                _teamColors[_teamControllers.indexOf(controller)] = color;
                              });
                            },
                            showLabel: true,
                            pickerAreaHeightPercent: 0.8,
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Done'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _teamColors[_teamControllers.indexOf(controller)],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        )),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _addTeamField();
            });
          },
          child: const Text('Add Another Team'),
        ),
      ],
    );
  }

  Widget _buildRaceLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Race Location:',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            key: ValueKey(isLocationButtonVisible),
            children: [
              Expanded(
                child: TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    hintText: (Platform.isIOS || Platform.isAndroid) ? 'Other Location' : 'Race Location',
                  ),
                  onChanged: (value) {
                    _updateLocationButtonVisibility();
                  },
                ),
              ),
              if (isLocationButtonVisible && (Platform.isIOS || Platform.isAndroid))
                TextButton(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined),
                      Text('My Location'),
                    ],
                  ),
                  onPressed: () async {
                    try {
                      LocationPermission permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }

                      if (permission == LocationPermission.deniedForever) {
                        DialogUtils.showErrorDialog(context, message: ('Location permissions are permanently denied, we cannot request permissions.'));
                        return;
                      }

                      if (permission == LocationPermission.denied) {
                        DialogUtils.showErrorDialog(context, message: ('Location permissions are denied, please enable them in settings.'));
                        return;
                      }

                      if (!await Geolocator.isLocationServiceEnabled()) {
                        DialogUtils.showErrorDialog(context, message: ('Location services are disabled'));
                        return;
                      }

                      final position = await Geolocator.getCurrentPosition();
                      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
                      final placemark = placemarks.first;
                      setState(() {
                        locationController.text = '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
                        userlocationController.text = locationController.text;
                      });
                      _updateLocationButtonVisibility();
                    } catch (e) {
                      print('Error getting location: $e');
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRaceDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Race Date:',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    hintText: 'Date (YYYY-MM-DD)',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    dateController.text = pickedDate.toLocal().toString().split(' ')[0];
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRaceDistanceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Race Distance:',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: distanceController,
                  decoration: InputDecoration(
                    hintText: '0.0',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              Spacer(),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    const Text('Unit: '),
                    DropdownButton<String>(
                      value: unit,
                      onChanged: (String? newValue) {
                        setState(() {
                          unit = newValue!;
                        });
                      },
                      items: <String>['miles', 'kilometers']
                        .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        })
                        .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _createRace() async {
    for (var controller in _teamControllers) {
      if (controller.text.isEmpty) {
        DialogUtils.showErrorDialog(context, message: ('Please fill in all the fields'));
        return;
      }
    }
    if (_teamControllers.length < 2) {
      DialogUtils.showErrorDialog(context, message: ('Please enter at least 2 teams'));
      return;
    }
    if (nameController.text.isEmpty ||
        locationController.text.isEmpty ||
        dateController.text.isEmpty ||
        distanceController.text.isEmpty) {
      DialogUtils.showErrorDialog(context, message: ('Please fill in all the fields'));
      return;
    }
    DateTime date;
    double distance;
    try {
      date = DateTime.parse(dateController.text);
      if (date.year < 1900) {
        DialogUtils.showErrorDialog(context, message: ('Date must be in the future'));
        return;
      }
      distance = double.parse(distanceController.text);
      if (distance < 0) {
        DialogUtils.showErrorDialog(context, message: ('Distance must be positive'));
        return;
      }
    } on FormatException {
      DialogUtils.showErrorDialog(context, message: ('Invalid date or distance'));
      return;
    }

    final List<String> teams = _teamControllers.map((controller) => controller.text).toList();
    final List<String> colors = _teamColors.map((color) => '0x${color.value.toRadixString(16).padLeft(8, '0')}').toList();

    final String raceName = nameController.text;

    final String distanceType = unit;

    final String distanceString = '${distance.toString().replaceAll(' ', '')} $distanceType';
    final id = await DatabaseHelper.instance.insertRace({
        'race_name': raceName,
        'location': locationController.text,
        'race_date': dateController.text,
        'distance': distanceString,
        'teams': jsonEncode(teams),
        'team_colors': jsonEncode(colors),
    });
    Navigator.pop(context);

    showModalBottomSheet(
      backgroundColor: AppColors.backgroundColor,
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: RaceInfoScreen(
          raceId: id,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd yyyy').format(date);
  }

  Future<bool> _isRaceStarted(Race race) async {
    final raceId = race.race_id;
    final results = await DatabaseHelper.instance.getRaceResults(raceId);
    return results.isNotEmpty;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRaceSheet(context),
        tooltip: 'Create new race',
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => showDeviceConnectionPopup(
                context,
                deviceType: DeviceType.browserDevice,
                deviceName: DeviceName.coach,
                otherDevices: createOtherDeviceList(
                  DeviceName.coach,
                  DeviceType.browserDevice
                ),
              ),
              child: Text('Recieve data'),
            
            ),
            buildRoleBar(context, 'coach', 'Races'),
            // const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: FutureBuilder<List<Race>>(
                  future: DatabaseHelper.instance.getAllRaces(),
                  builder: (context, snapshot){
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Text('No races found.'));
                    }
                    races = snapshot.data ?? [];

                    return FutureBuilder<List<bool>>(
                      future: Future.wait(races.map((race) => _isRaceStarted(race)).toList()),
                      builder: (context, finishedSnapshot) {
                        if (finishedSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final finishedRaces = finishedSnapshot.data ?? List.filled(races.length, false);

                        return ListView.builder(
                          itemCount: races.length,
                          itemBuilder: (context, index) {
                            return Card(
                              color: finishedRaces[index] ? Colors.green[100] : Colors.amber,
                              child: ListTile(
                                title: Text(races[index].race_name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                                subtitle: finishedRaces[index] ? Text(_formatDate(races[index].race_date), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400))
                                  : Text('${_formatDate(races[index].race_date)} - Race not completed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.red)),
                                onTap: () {
                                  showModalBottomSheet(
                                    backgroundColor: AppColors.backgroundColor,
                                    context: context,
                                    isScrollControlled: true,
                                    enableDrag: true,
                                    useSafeArea: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                    ),
                                    builder: (context) => SizedBox(
                                      height: MediaQuery.of(context).size.height * 0.92,
                                      child: RaceInfoScreen(
                                        raceId: races[index].raceId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            )
          ]
      ),
      )
    );
  }
}