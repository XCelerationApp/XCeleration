import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'race_screen.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/race.dart';
import '../database_helper.dart';
import '../utils/app_colors.dart';
import '../utils/textfield_utils.dart';
import '../utils/dialog_utils.dart';
import 'dart:io';
import '../role_functions.dart';
import '../utils/sheet_utils.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class RacesScreen extends StatefulWidget {
  const RacesScreen({super.key});

  @override
  _RacesScreenState createState() => _RacesScreenState();
}


class _RacesScreenState extends State<RacesScreen> {
  List<Race> races = [];
  bool isLocationButtonVisible = true;
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final dateController = TextEditingController();
  final distanceController = TextEditingController();
  final unitController = TextEditingController();
  final userlocationController = TextEditingController();
  List<TextEditingController> _teamControllers = [];
  List<Color> _teamColors = [];
  String unit = 'mi';
  
  // Validation error messages
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;
  String? teamsError;

  @override
  void initState() {
    super.initState();
    _loadRaces();
    _teamControllers.add(TextEditingController());
    _teamControllers.add(TextEditingController());
    _teamColors.add(Colors.white);
    _teamColors.add(Colors.white);
    unitController.text = 'mi';
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _validateName(name, StateSetter setSheetState) {
    setSheetState(() {
      if (name.isEmpty) {
        nameError = 'Please enter a race name';
      } else {
        nameError = null;
      }
    });
  }

  void _validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      if (location.isEmpty) {
        locationError = 'Please enter a location';
      } else {
        locationError = null;
      }
    });
  }

  void _validateDate(String dateString, StateSetter setSheetState) {
    setSheetState(() {
      if (dateString.isEmpty) {
        dateError = 'Please select a date';
      } else {
        try {
          final date = DateTime.parse(dateString);
          if (date.year < 1900) {
            dateError = 'Invalid date';
          } else {
            dateError = null;
          }
        } catch (e) {
          dateError = 'Invalid date format';
        }
      }
    });
  }

  void _validateDistance(String distanceString, StateSetter setSheetState) {
    setSheetState(() {
      if (distanceString.isEmpty) {
        distanceError = 'Please enter a distance';
      } else {
        try {
          final distance = double.parse(distanceString);
          if (distance <= 0) {
            distanceError = 'Distance must be greater than 0';
          } else {
            distanceError = null;
          }
        } catch (e) {
          distanceError = 'Invalid number';
        }
      }
    });
  }

  String? _getFirstError() {
    if (nameController.text.isEmpty) {
      return 'Please enter a race name';
    }
    if (locationController.text.isEmpty) {
      return 'Please enter a race location';
    }
    if (dateController.text.isEmpty) {
      return 'Please select a race date';
    } else {
      try {
        final date = DateTime.parse(dateController.text);
        if (date.year < 1900) {
          return 'Invalid date';
        }
      } catch (e) {
        return 'Invalid date format';
      }
    }
    if (distanceController.text.isEmpty) {
      return 'Please enter a race distance';
    } else {
      try {
        final distance = double.parse(distanceController.text);
        if (distance <= 0) {
          return 'Distance must be greater than 0';
        }
      } catch (e) {
        return 'Invalid distance';
      }
    }
    
    List<String> teams = _teamControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (teams.isEmpty) {
      return 'Please add at least one team';
    }
    
    return null;
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
    });
  }

  // Method to add a new TextEditingController
  void _addTeamField() {
    setState(() {
      _teamControllers.add(TextEditingController());
      _teamColors.add(Colors.white);
    });
  }

  void _showCreateRaceSheet(BuildContext context) {
    _resetControllers();

    sheet(context: context, title: 'Create New Race', body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return _buildCreateRaceSheetContent(setSheetState);
        },
      ));
  }

  Widget _buildCreateRaceSheetContent(StateSetter setSheetState, {bool isEditing = false, int? raceId}) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // _buildCreateRaceSheetTitle(isEditing: isEditing),
          _buildRaceNameField(setSheetState),
          SizedBox(height: 12),
          _buildCompetingTeamsField(setSheetState),
          SizedBox(height: 12),
          _buildRaceLocationField(setSheetState),
          SizedBox(height: 12),
          _buildRaceDateField(setSheetState),
          SizedBox(height: 12),
          _buildRaceDistanceField(setSheetState),
          SizedBox(height: 12),
          _buildActionButton(isEditing: isEditing, raceId: raceId),
        ],
      ),
    );
  }

  // Widget _buildCreateRaceSheetTitle({bool isEditing = false}) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 16),
  //     child: Text(
  //       isEditing ? 'Edit Race' : 'Create New Race',
  //       style: const TextStyle(
  //         fontSize: 24,
  //         fontWeight: FontWeight.bold,
  //       ),
  //       textAlign: TextAlign.center,
  //     ),
  //   );
  // }

  Widget _buildActionButton({bool isEditing = false, int? raceId}) {
    return ElevatedButton(
        onPressed: () async {
          final error = _getFirstError();
          if (error != null) {
            DialogUtils.showErrorDialog(
              context,
              message: error,
            );
            return;
          }

          final race = {
            'race_name': nameController.text,
            'location': locationController.text,
            'race_date': dateController.text,
            'distance': double.parse(distanceController.text),
            'distance_unit': unit,
            'teams': jsonEncode(_teamControllers
                .map((controller) => controller.text.trim())
                .where((text) => text.isNotEmpty)
                .toList()),
            'team_colors': jsonEncode(_teamColors.map((color) => color.value).toList()),
          };

          if (isEditing && raceId != null) {
            race['race_id'] = raceId;
            await DatabaseHelper.instance.updateRace(race);
          } else {
            await DatabaseHelper.instance.insertRace(race);
          }
          await _loadRaces();

          if (mounted) {
            Navigator.pop(context);
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.primaryColor,
          fixedSize: const Size.fromHeight(64),
        ),
        child: Text(
          isEditing ? 'Save Changes' : 'Create Race',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
    );
  }

  void _resetControllers() {
    nameController.text = '';
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
    unitController.text = 'mi';
    nameError = null;
    locationError = null;
    dateError = null;
    distanceError = null;
    teamsError = null;
  }

  Widget _buildRaceNameField(StateSetter setSheetState) {
    return buildInputRow(
      label: 'Name',
      inputWidget: buildTextField(
        controller: nameController,
        hint: 'Enter race name',
        error: nameError,
        onChanged: (_) => _validateName(nameController.text, setSheetState),
        setSheetState: setSheetState,
      ),
    );
  }

  Widget _buildCompetingTeamsField(StateSetter setSheetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Competing Teams',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        if (teamsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              teamsError!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ..._teamControllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: buildTextField(
                    controller: controller,
                    hint: 'Team name',
                    onChanged: (value) {
                      setSheetState(() {
                        teamsError = _teamControllers.every(
                          (controller) => controller.text.trim().isEmpty)
                            ? 'Please enter in team name'
                            : null;
                      });
                    },
                    setSheetState: setSheetState,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showColorPicker(setSheetState, controller),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _teamColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_teamControllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () {
                      setSheetState(() {
                        _teamControllers.removeAt(index);
                        _teamColors.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            setSheetState(() {
              _addTeamField();
            });
          },
          icon: Icon(Icons.add_circle_outline, color: AppColors.primaryColor),
          label: Text(
            'Add Another Team',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRaceLocationField(StateSetter setSheetState) {
    return buildInputRow(
      label: 'Location',
      inputWidget: Row(
        children: [
          Expanded(
            flex: 2,
            child: buildTextField(
              controller: locationController,
              hint: (Platform.isIOS || Platform.isAndroid)
                  ? 'Other location'
                  : 'Enter race location',
              error: locationError,
              setSheetState: setSheetState,
              onChanged: (_) => _validateLocation(locationController.text, setSheetState),
              keyboardType: TextInputType.text,
            ),
          ),
          if (isLocationButtonVisible && (Platform.isIOS || Platform.isAndroid)) ...[
           const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: IconButton(
                icon: Icon(Icons.my_location, color: AppColors.primaryColor),
                onPressed: _getCurrentLocation,
              )
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRaceDateField(StateSetter setSheetState) {
    return buildInputRow(
      label: 'Date',
      inputWidget: buildTextField(
        controller: dateController,
        hint: 'YYYY-MM-DD',
        error: dateError,
        suffixIcon: IconButton(
          icon: Icon(Icons.calendar_today, color: AppColors.primaryColor),
          onPressed: () => _selectDate(context),
        ),
        setSheetState: setSheetState,
        onChanged: (_) => _validateDate(dateController.text, setSheetState),
      ),
    );
  }

  Widget _buildRaceDistanceField(StateSetter setSheetState) {
    return buildInputRow(
      label: 'Distance',
      inputWidget: Row(
        children: [
          Expanded(
            flex: 2,
            child: buildTextField(
              controller: distanceController,
              hint: '0.0',
              error: distanceError,
              setSheetState: setSheetState,
              onChanged: (_) => _validateDistance(distanceController.text, setSheetState),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: buildDropdown(
              controller: unitController,
              hint: 'mi',
              error: null,
              setSheetState: setSheetState,
              items: ['mi', 'km'],
              onChanged: (_) => null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        DialogUtils.showErrorDialog(context, message: 'Location permissions are permanently denied');
        return;
      }

      if (permission == LocationPermission.denied) {
        DialogUtils.showErrorDialog(context, message: 'Location permissions are denied');
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        DialogUtils.showErrorDialog(context, message: 'Location services are disabled');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      final placemark = placemarks.first;
      setState(() {
        locationController.text = '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
        userlocationController.text = locationController.text;
        locationError = null;
      });
      _updateLocationButtonVisibility();
    } catch (e) {
      print('Error getting location: $e');
      DialogUtils.showErrorDialog(context, message: 'Could not get location');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        dateController.text = picked.toLocal().toString().split(' ')[0];
        dateError = null;
      });
    }
  }

  void _showColorPicker(StateSetter setSheetState, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: _teamColors[_teamControllers.indexOf(controller)],
              onColorChanged: (color) {
                setSheetState(() {
                  _teamColors[_teamControllers.indexOf(controller)] = color;
                });
              },
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
  }

  void _showRaceScreen(int raceId) {
    sheet(
      context: context,
      showHeader: false,
      body: RaceScreen(raceId: raceId), 
      title: races.firstWhere((race) => race.raceId == raceId).raceName, 
    );
  }

  Widget _buildRaceCard(Race race) {
    return Slidable(
      key: Key(race.raceId.toString()),
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const DrawerMotion(),
        dragDismissible: false,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _editRace(race),
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            autoClose: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 24,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => _deleteRace(race),
            backgroundColor: AppColors.primaryColor.withRed(255),
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            autoClose: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 24,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        width: double.infinity,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showRaceScreen(race.raceId),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    race.raceName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          race.location,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y').format(race.raceDate),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.directions_run, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '${race.distance} ${race.distanceUnit}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editRace(Race race) async {
    // Pre-fill the controllers with race data
    nameController.text = race.raceName;
    locationController.text = race.location;
    dateController.text = DateFormat('yyyy-MM-dd').format(race.raceDate);
    distanceController.text = race.distance.toString();
    unit = race.distanceUnit;

    // Clear existing team controllers
    for (var controller in _teamControllers) {
      controller.dispose();
    }
    _teamControllers.clear();
    _teamColors.clear();

    // Add team controllers for existing teams
    for (var i = 0; i < race.teams.length; i++) {
      var controller = TextEditingController(text: race.teams[i]);
      _teamControllers.add(controller);
      _teamColors.add(race.teamColors[i]);
    }

    // Show the edit sheet
    await sheet(
      context: context,
      title: 'Edit Race',
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.92,
              child: _buildCreateRaceSheetContent(
                setSheetState,
                isEditing: true,
                raceId: race.raceId,
              ),
            ),
          );
        },
      ),
    );

    // Reload races after editing
    await _loadRaces();
  }

  Future<void> _deleteRace(Race race) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Race',
      content: 'Are you sure you want to delete "${race.raceName}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteRace(race.raceId);
      await _loadRaces();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRaceSheet(context),
        // tooltip: 'Create new race',
        backgroundColor: AppColors.primaryColor,
        child: Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
        child: Column(
          children: [
            buildRoleBar(context, 'coach', 'Races'),
            const SizedBox(height: 15),
            Expanded(
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

                  return ListView.builder(
                    itemCount: races.length,
                    itemBuilder: (context, index) {
                      return _buildRaceCard(races[index]);
                    },
                  );
                },
              ),
            )
          ]
      ),
      )
    );
  }
}