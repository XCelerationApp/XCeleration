import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:xceleration/coach/races_screen/widgets/race_creation_sheet.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/sheet_utils.dart' show sheet;
import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/services/event_bus.dart';
import 'dart:async';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../shared/role_bar/role_bar.dart';
import '../../race_screen/controller/race_screen_controller.dart';
import '../services/races_service.dart';

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
    _eventSubscription =
        EventBus.instance.on(EventTypes.raceFlowStateChanged, (event) {
      // Reload races when any race's flow state changes
      loadRaces();
    });
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
      final masterRace = MasterRace.getInstance(newRaceId);

      if (context.mounted) {
        await RaceController.showRaceScreen(context, this, masterRace);
      }
    }
  }

  void validateName(name, StateSetter setSheetState) {
    setSheetState(() {
      nameError = RacesService.validateName(name);
    });
  }

  void validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      locationError = RacesService.validateLocation(location);
    });
  }

  void validateDate(String dateString, StateSetter setSheetState) {
    setSheetState(() {
      dateError = RacesService.validateDate(dateString);
    });
  }

  void validateDistance(String distanceString, StateSetter setSheetState) {
    setSheetState(() {
      distanceError = RacesService.validateDistance(distanceString);
    });
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

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

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

      bool locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!context.mounted) return; // Check if context is still valid

      if (!locationEnabled) {
        DialogUtils.showErrorDialog(context,
            message: 'Location services are disabled');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!context.mounted) return; // Check if context is still valid
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (!context.mounted) return; // Check if context is still valid

      final placemark = placemarks.first;
      locationController.text =
          '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
      userlocationController.text = locationController.text;
      locationError = null;
      notifyListeners();
      updateLocationButtonVisibility();
    } catch (e) {
      Logger.d('Error getting location: $e');
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
    if (race.raceId == null) {
      throw Exception('Race ID is null');
    }
    final masterRace = MasterRace.getInstance(race.raceId!);
    await RaceController.showRaceScreen(context, this, masterRace);
  }

  Future<void> deleteRace(Race race) async {
    if (race.raceId == null) {
      throw Exception('Race ID is null');
    }
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Delete Race',
      content:
          'Are you sure you want to delete "${race.raceName}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      await RacesService.deleteRace(race.raceId!);
      await loadRaces();
    }
  }

  // Create a new race with minimal information
  Future<int> createRace(Race race) async {
    final newRaceId = await RacesService.createRace(race);
    await loadRaces(); // Refresh the races list
    return newRaceId;
  }

  // Update an existing race
  Future<void> updateRace(Race race) async {
    await RacesService.updateRace(race);
    await loadRaces(); // Refresh the races list
  }

  Future<void> loadRaces() async {
    races = await RacesService.loadRaces();
    Logger.d('Races loaded: ${races.length}');
    notifyListeners();
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
