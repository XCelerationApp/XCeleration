import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:race_timing_app/screens/race_info_screen.dart';
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
    });
  }


  // // Method to show the create race dialog
  // void _showCreateRaceDialog(BuildContext context) {
  //   nameController.text = 'Untitled Race';
  //   locationController.text = '';
  //   dateController.text = '';
  //   distanceController.text = '';
  //   userlocationController.text = '';
  //   isLocationButtonVisible = true;
  //   _teamControllers.clear();
  //   _teamControllers.add(TextEditingController());
  //   _teamControllers.add(TextEditingController());

  void _showCreateRaceSheet(BuildContext context) {
    nameController.text = 'Untitled Race';
    locationController.text = '';
    dateController.text = '';
    distanceController.text = '';
    userlocationController.text = '';
    isLocationButtonVisible = true;
    _teamControllers.clear();
    _teamControllers.add(TextEditingController());
    _teamControllers.add(TextEditingController());

    showModalBottomSheet(
      backgroundColor: AppColors.backgroundColor,
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    createSheetHandle(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Create a New Race',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Column(
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
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Team Name',
                              border: OutlineInputBorder(),
                            ),
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
                    ),
                    Column(
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
                    ),
                    Column(
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
                    ),
                    Column(
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
                                  keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
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
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Expanded(
                            child: ElevatedButton(
                              onPressed: _createRace,
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(350, 75),
                                backgroundColor: AppColors.primaryColor,
                              ),
                              child: const Text('Create', style: TextStyle(color: AppColors.backgroundColor, fontSize: 30)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    if (locationController.text.isEmpty ||
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

    final String raceName = _teamControllers.map((controller) => controller.text).toList().join(' vs ');

    final String distanceType = unit;

    final distranceString = '${distance.toString().replaceAll(' ', '')} $distanceType';
    final id = await DatabaseHelper.instance.insertRace({
        'race_name': raceName,
        'location': locationController.text,
        'race_date': dateController.text,
        'distance': distranceString,
    });
    // final race = Race(
    //   raceId: id,
    //   raceName: raceName,
    //   location: locationController.text,
    //   raceDate: date,
    //   distance: distranceString,
    // );
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => RaceInfoScreen(raceId: id),
    //   ),
    // );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: AppColors.backgroundColor,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: RaceInfoScreen(
          raceId: id,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          buildRoleBar(context, 'coach', 'Races'),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FutureBuilder<List<Race>>(
                future: DatabaseHelper.instance.getAllRaces(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No races found.'));
                  }
                  races = snapshot.data ?? [];

                  return ListView.builder(
                    itemCount: races.length,
                    itemBuilder: (context, index) {
                      return Card(
                        child: ListTile(
                          trailing: GestureDetector(
                            child: Icon(Icons.delete, color: AppColors.navBarColor),
                            onTap: () async {
                              final confirmed = await DialogUtils.showConfirmationDialog(context, content:'Are you sure you want to delete ${races[index].race_name}?', title: 'Delete race');
                              if (!confirmed) return;
                              await DatabaseHelper.instance.deleteRace(races[index].raceId);
                              final newRaces = await DatabaseHelper.instance.getAllRaces();
                              setState(() {
                                races = newRaces;
                              });
                            },
                          ),
                          title: Text(races[index].race_name),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: AppColors.backgroundColor,
                              builder: (context) => Container(
                                height: MediaQuery.of(context).size.height * 0.92,
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
              ),
            ),
          )
        ]
     ),

     floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRaceSheet(context),
        tooltip: 'Create new race',
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add),
      ),
    );
  }
}