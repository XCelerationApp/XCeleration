import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xcelerate/coach/races_screen/widgets/race_creation_sheet.dart';
import 'package:xcelerate/coach/runners_management_screen/screen/runners_management_screen.dart';
import 'package:xcelerate/core/components/dialog_utils.dart';
import 'package:xcelerate/utils/database_helper.dart' show DatabaseHelper;
import 'package:xcelerate/utils/sheet_utils.dart' show sheet;
import '../../../shared/models/race.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/services/event_bus.dart';
import 'dart:async';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../shared/role_bar/role_bar.dart';
import '../../race_screen/controller/race_screen_controller.dart';

class RacesController extends ChangeNotifier {
  // Subscription to event bus events
  StreamSubscription? _eventSubscription;

  List<Race> races = [];
  bool isLocationButtonVisible = true;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController userlocationController = TextEditingController();
  final List<TextEditingController> teamControllers = [];
  final List<Color> teamColors = [];
  String unit = 'mi';

  final TutorialManager tutorialManager = TutorialManager();

  // Validation error messages
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;
  String? teamsError;

  BuildContext? _context;

  RacesController();

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in RacesController. Call setContext() first.');
    return _context!;
  }

  void initState() {
    loadRaces();
    teamControllers.add(TextEditingController());
    teamControllers.add(TextEditingController());
    teamColors.add(Colors.white);
    teamColors.add(Colors.white);
    unitController.text = 'mi';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RoleBar.showInstructionsSheet(context, Role.coach).then((_) {
        if (context.mounted) setupTutorials();
      });
    });
    
    // Subscribe to race flow state change events
    _eventSubscription = EventBus.instance.on(EventTypes.raceFlowStateChanged, (event) {
      // Reload races when any race's flow state changes
      loadRaces();
    });
  }

  Future<void> loadRaces() async {
    races = await DatabaseHelper.instance.getAllRaces();
    notifyListeners();
  }

  void setupTutorials() {
    tutorialManager.startTutorial([
      'race_swipe_tutorial',
      'role_bar_tutorial',
      'create_race_button_tutorial'
    ]);
  }

  void updateLocationButtonVisibility() {
    isLocationButtonVisible =
        locationController.text.trim() != userlocationController.text.trim();
    notifyListeners();
  }

  // Method to add a new TextEditingController
  void addTeamField() {
    teamControllers.add(TextEditingController());
    teamColors.add(Colors.white);
    notifyListeners();
  }

  Future<void> showCreateRaceSheet(BuildContext context) async {
    resetControllers();

    // Show the race creation sheet and await the returned race ID
    final int? newRaceId = await sheet(
      context: context,
      title: 'Create New Race',
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return RaceCreationSheet(
            controller: this,
            setSheetState: setSheetState,
          );
        },
      ),
    );
    
    // If a valid race ID was returned and the context is still mounted,
    // navigate to the race screen
    if (newRaceId != null && context.mounted) {
      // Add a small delay to let the UI settle after sheet dismissal
      await Future.delayed(const Duration(milliseconds: 300));

      if (context.mounted) {
        await RaceController.showRaceScreen(context, this, newRaceId);
      }
    }
  }

  void validateName(name, StateSetter setSheetState) {
    setSheetState(() {
      if (name.isEmpty) {
        nameError = 'Please enter a race name';
      } else {
        nameError = null;
      }
    });
  }

  void validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      if (location.isEmpty) {
        locationError = 'Please enter a location';
      } else {
        locationError = null;
      }
    });
  }

  void validateDate(String dateString, StateSetter setSheetState) {
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

  void validateDistance(String distanceString, StateSetter setSheetState) {
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

  String? getFirstError() {
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

    List<String> teams = teamControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (teams.isEmpty) {
      return 'Please add at least one team';
    }

    return null;
  }

  void resetControllers() {
    nameController.text = '';
    locationController.text = '';
    dateController.text = '';
    distanceController.text = '';
    userlocationController.text = '';
    isLocationButtonVisible = true;
    teamControllers.clear();
    teamControllers.add(TextEditingController());
    teamControllers.add(TextEditingController());
    teamColors.clear();
    teamColors.add(Colors.white);
    teamColors.add(Colors.white);
    unitController.text = 'mi';
    nameError = null;
    locationError = null;
    dateError = null;
    distanceError = null;
    teamsError = null;
    
    notifyListeners();
  }

  bool validateRaceName() {
    if (nameController.text.trim().isEmpty) {
      nameError = 'Race name is required';
      notifyListeners();
      return false;
    }
    nameError = null;
    notifyListeners();
    return true;
  }
  
  // For simplified creation, we only validate the race name
  bool validateRaceCreation() {
    return validateRaceName();
  }

  // Checks if all required fields are filled for a complete setup
  Future<bool> isSetupComplete(Race race) async {
    final moreThanFiveRunnersPerTeam = await RunnersManagementScreen.checkMinimumRunnersLoaded(race.raceId);
    return race.raceName.isNotEmpty && 
           race.location.isNotEmpty && 
           race.raceDate != null && 
           race.distance > 0 &&
           race.distanceUnit.isNotEmpty && 
           race.teams.isNotEmpty &&
           race.teamColors.isNotEmpty &&
           moreThanFiveRunnersPerTeam;
  }

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        DialogUtils.showErrorDialog(context,
            message: 'Location permissions are permanently denied');
        return;
      }

      if (permission == LocationPermission.denied) {
        DialogUtils.showErrorDialog(context,
            message: 'Location permissions are denied');
        return;
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        DialogUtils.showErrorDialog(context,
            message: 'Location services are disabled');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      final placemark = placemarks.first;
      locationController.text =
          '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
      userlocationController.text = locationController.text;
      locationError = null;
      notifyListeners();
      updateLocationButtonVisibility();
    } catch (e) {
      debugPrint('Error getting location: $e');
      DialogUtils.showErrorDialog(context, message: 'Could not get location');
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      dateController.text = picked.toLocal().toString().split(' ')[0];
      dateError = null;
      notifyListeners();
    }
  }

  void showColorPicker(
      StateSetter setSheetState, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: teamColors[teamControllers.indexOf(controller)],
              onColorChanged: (color) {
                setSheetState(() {
                  teamColors[teamControllers.indexOf(controller)] = color;
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

  Future<void> editRace(Race race) async {
    await RaceController.showRaceScreen(context, this, race.raceId);
  }

  Future<void> deleteRace(Race race) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Race',
      content:
          'Are you sure you want to delete "${race.raceName}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteRace(race.raceId);
      await loadRaces();
    }
  }

  // Create a new race with minimal information
  Future<int> createRace(Race race) async {
    final newRaceId = await DatabaseHelper.instance.insertRace(race);
    await loadRaces(); // Refresh the races list
    return newRaceId;
  }
  
  // Update an existing race
  Future<void> updateRace(Race race) async {
    await DatabaseHelper.instance.updateRace(race);
    await loadRaces(); // Refresh the races list
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
    distanceController.dispose();
    userlocationController.dispose();
    unitController.dispose();
    for (var controller in teamControllers) {
      controller.dispose();
    }
    teamColors.clear();
    tutorialManager.dispose();
    _context = null;
    _eventSubscription?.cancel();
    super.dispose();
  }
}
