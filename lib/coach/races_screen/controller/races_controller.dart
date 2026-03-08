import 'package:flutter/material.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:xceleration/coach/races_screen/widgets/race_creation_sheet.dart';
import 'package:xceleration/core/services/color_picker_dialog_service.dart';
import 'package:xceleration/core/services/date_picker_service.dart';
import 'package:xceleration/core/services/geo_location_service.dart';
import 'package:xceleration/core/services/post_frame_callback_scheduler.dart';
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

  final IRacesService _racesService;
  final IAuthService _authService;
  final IEventBus _eventBus;
  final IGeoLocationService _geoLocationService;
  final IPostFrameCallbackScheduler _postFrameCallbackScheduler;
  final IDatePickerService _datePickerService;
  final IColorPickerDialogService _colorPickerDialogService;

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

  final TutorialManager tutorialManager;

  // Validation error messages
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;
  String? teamsError;

  final bool canEdit;

  RacesController({
    required IRacesService racesService,
    required IAuthService authService,
    required IEventBus eventBus,
    required IGeoLocationService geoLocationService,
    required IPostFrameCallbackScheduler postFrameCallbackScheduler,
    required this.tutorialManager,
    IDatePickerService? datePickerService,
    IColorPickerDialogService? colorPickerDialogService,
    this.canEdit = true,
  })  : _racesService = racesService,
        _authService = authService,
        _eventBus = eventBus,
        _geoLocationService = geoLocationService,
        _postFrameCallbackScheduler = postFrameCallbackScheduler,
        _datePickerService = datePickerService ?? DatePickerService(),
        _colorPickerDialogService =
            colorPickerDialogService ?? ColorPickerDialogService();

  void initState(BuildContext context) {
    loadRaces();
    teamControllers.add(TextEditingController());
    teamControllers.add(TextEditingController());
    teamColors.add(Colors.white);
    teamColors.add(Colors.white);
    unitController.text = 'mi';
    _postFrameCallbackScheduler.addPostFrameCallback(() {
      final role = canEdit ? Role.coach : Role.spectator;
      RoleBar.showInstructionsSheet(context, role).then((_) {
        if (context.mounted) setupTutorials();
      });
    });

    // Subscribe to race flow state change events
    _eventSubscription =
        _eventBus.on(EventTypes.raceFlowStateChanged, (event) {
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
      body: RaceCreationSheet(controller: this),
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

  void validateName(String name) {
    nameError = _racesService.validateName(name);
    notifyListeners();
  }

  void validateLocation(String location) {
    locationError = _racesService.validateLocation(location);
    notifyListeners();
  }

  void validateDate(String dateString) {
    dateError = _racesService.validateDate(dateString);
    notifyListeners();
  }

  void validateDistance(String distanceString) {
    distanceError = _racesService.validateDistance(distanceString);
    notifyListeners();
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

  Future<void> getCurrentLocation(BuildContext context) async {
    try {
      LocationPermission permission =
          await _geoLocationService.checkPermission();

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await _geoLocationService.requestPermission();
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

      bool locationEnabled =
          await _geoLocationService.isLocationServiceEnabled();
      if (!context.mounted) return; // Check if context is still valid

      if (!locationEnabled) {
        DialogUtils.showErrorDialog(context,
            message: 'Location services are disabled');
        return;
      }

      final position = await _geoLocationService.getCurrentPosition();
      if (!context.mounted) return; // Check if context is still valid
      final placemarks = await _geoLocationService.placemarkFromCoordinates(
          position.latitude, position.longitude);
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
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Could not get location');
      }
    }
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await _datePickerService.pickDate(context);
    if (picked != null) {
      dateController.text = picked.toLocal().toString().split(' ')[0];
      dateError = null;
      notifyListeners();
    }
  }

  void showColorPicker(
      BuildContext context,
      StateSetter setSheetState,
      TextEditingController controller) {
    final index = teamControllers.indexOf(controller);
    _colorPickerDialogService.showColorPicker(
      context,
      currentColor: teamColors[index],
      onColorChanged: (color) {
        setSheetState(() {
          teamColors[index] = color;
        });
      },
    );
  }

  Future<void> editRace(Race race, BuildContext context) async {
    if (race.raceId == null) {
      throw Exception('Race ID is null');
    }
    // Only owner can edit
    final currentUserId = _authService.currentUserId;
    if (race.ownerUserId != null &&
        currentUserId != null &&
        race.ownerUserId != currentUserId) {
      DialogUtils.showErrorDialog(context,
          message: 'Only the coach who created this race can edit it.');
      return;
    }
    final masterRace = MasterRace.getInstance(race.raceId!);
    await RaceController.showRaceScreen(context, this, masterRace);
  }

  Future<void> deleteRace(Race race, BuildContext context) async {
    if (race.raceId == null) {
      throw Exception('Race ID is null');
    }
    // Only owner can delete
    final currentUserId = _authService.currentUserId;
    if (race.ownerUserId != null &&
        currentUserId != null &&
        race.ownerUserId != currentUserId) {
      DialogUtils.showErrorDialog(context,
          message: 'Only the coach who created this race can delete it.');
      return;
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
      await _racesService.deleteRace(race.raceId!);
      MasterRace.clearInstance(race.raceId!);
      await loadRaces();
    }
  }

  // Create a new race with minimal information
  Future<int> createRace(Race race) async {
    final newRaceId = await _racesService.createRace(race);
    await loadRaces(); // Refresh the races list
    return newRaceId;
  }

  // Update an existing race
  Future<void> updateRace(Race race) async {
    await _racesService.updateRace(race);
    await loadRaces(); // Refresh the races list
  }

  Future<void> loadRaces() async {
    races = await _racesService.loadRaces();
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
    _eventSubscription?.cancel();
    super.dispose();
  }
}
