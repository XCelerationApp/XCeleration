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
import '../../../core/services/sync_service.dart';
import 'dart:async';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../shared/role_bar/role_bar.dart';
import 'package:provider/provider.dart';
import '../../race_screen/controller/race_screen_controller.dart';
import '../../race_screen/screen/race_screen.dart';
import '../services/races_service.dart';
import 'i_parent_race_controller.dart';
import 'race_creation_form_state.dart';

class RacesController extends ChangeNotifier implements IParentRaceController {
  // Subscription to event bus events
  StreamSubscription? _eventSubscription;
  StreamSubscription? _syncSubscription;

  final Stream<SyncEvent>? _syncStream;

  final IRacesService _racesService;
  final IAuthService _authService;
  final IEventBus _eventBus;
  final IGeoLocationService _geoLocationService;
  final IPostFrameCallbackScheduler _postFrameCallbackScheduler;
  final IDatePickerService _datePickerService;
  final IColorPickerDialogService _colorPickerDialogService;

  List<Race> races = [];

  // All race creation form state is owned by this form object.
  // Widgets that consumed controller.nameController etc. should now access
  // the same-named getters below, which delegate to [form].
  final RaceCreationFormState form = RaceCreationFormState();

  // Delegating getters — maintain backward compatibility with widgets that
  // access form fields directly on the controller.
  TextEditingController get nameController => form.nameController;
  TextEditingController get locationController => form.locationController;
  TextEditingController get dateController => form.dateController;
  TextEditingController get distanceController => form.distanceController;
  TextEditingController get unitController => form.unitController;
  TextEditingController get userLocationController =>
      form.userLocationController;
  List<TextEditingController> get teamControllers => form.teamControllers;
  List<Color> get teamColors => form.teamColors;

  ValueNotifier<String?> get nameErrorNotifier => form.nameErrorNotifier;
  ValueNotifier<String?> get locationErrorNotifier =>
      form.locationErrorNotifier;
  ValueNotifier<String?> get dateErrorNotifier => form.dateErrorNotifier;
  ValueNotifier<String?> get distanceErrorNotifier =>
      form.distanceErrorNotifier;
  ValueNotifier<bool> get locationButtonVisibleNotifier =>
      form.locationButtonVisibleNotifier;

  String? get nameError => form.nameError;
  set nameError(String? v) => form.nameError = v;
  String? get locationError => form.locationError;
  set locationError(String? v) => form.locationError = v;
  String? get dateError => form.dateError;
  set dateError(String? v) => form.dateError = v;
  String? get distanceError => form.distanceError;
  set distanceError(String? v) => form.distanceError = v;
  bool get isLocationButtonVisible => form.isLocationButtonVisible;
  set isLocationButtonVisible(bool v) => form.isLocationButtonVisible = v;

  // teamsError intentionally remains a plain String? field (not ValueNotifier)
  // because it is consumed via setSheetState in competing_teams_field.dart,
  // not via a targeted ValueNotifier subscription.
  String? teamsError;

  @override
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
    Stream<SyncEvent>? syncStream,
    this.canEdit = true,
  })  : _racesService = racesService,
        _authService = authService,
        _eventBus = eventBus,
        _geoLocationService = geoLocationService,
        _postFrameCallbackScheduler = postFrameCallbackScheduler,
        _syncStream = syncStream,
        _datePickerService = datePickerService ?? DatePickerService(),
        _colorPickerDialogService =
            colorPickerDialogService ?? ColorPickerDialogService();

  final TutorialManager tutorialManager;

  void initState(BuildContext context) {
    loadRaces();
    _postFrameCallbackScheduler.addPostFrameCallback(() {
      final role = canEdit ? Role.coach : Role.spectator;
      RoleBar.showInstructionsSheet(context, role).then((_) {
        if (context.mounted) setupTutorials();
      });
    });

    // Subscribe to race flow state change events
    _eventSubscription =
        _eventBus.on(EventTypes.raceFlowStateChanged, (event) {
      loadRaces();
    });

    // Reload races when a sync pull writes new race data
    _syncSubscription = _syncStream
        ?.where((event) => event.changedTables.contains('races'))
        .listen((_) => loadRaces());
  }

  void setupTutorials() {
    tutorialManager.startTutorial([
      'race_swipe_tutorial',
      'role_bar_tutorial',
      'create_race_button_tutorial'
    ]);
  }

  void updateLocationButtonVisibility() =>
      form.updateLocationButtonVisibility();

  // Method to add a new TextEditingController
  void addTeamField() {
    form.addTeamField();
    notifyListeners();
  }

  Future<void> showCreateRaceSheet(BuildContext context) async {
    form.reset();
    teamsError = null;

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
        await _openRaceSheet(context, masterRace);
      }
    }
  }

  Future<void> _openRaceSheet(BuildContext context, MasterRace masterRace) async {
    await sheet(
      context: context,
      body: ChangeNotifierProvider(
        create: (ctx) {
          final raceController = RaceScreenController(
            masterRace: masterRace,
            parentController: this,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            raceController.loadAllData(ctx);
          });
          return raceController;
        },
        child: RaceScreen(
          masterRace: masterRace,
          parentController: this,
        ),
      ),
      takeUpScreen: false,
      showHeader: true,
    );
    await loadRaces();
  }

  void validateName(String name) {
    form.nameErrorNotifier.value = _racesService.validateName(name);
  }

  void validateLocation(String location) {
    form.locationErrorNotifier.value = _racesService.validateLocation(location);
  }

  void validateDate(String dateString) {
    form.dateErrorNotifier.value = _racesService.validateDate(dateString);
  }

  void validateDistance(String distanceString) {
    form.distanceErrorNotifier.value =
        _racesService.validateDistance(distanceString);
  }

  void resetControllers() {
    form.reset();
    teamsError = null;
    notifyListeners();
  }

  bool validateRaceName() => form.validateRaceName();

  // For simplified creation, we only validate the race name
  bool validateRaceCreation() => form.validateRaceCreation();

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
      form.locationController.text =
          '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
      form.userLocationController.text = form.locationController.text;
      form.locationErrorNotifier.value = null;
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
      form.dateController.text = picked.toLocal().toString().split(' ')[0];
      form.dateErrorNotifier.value = null;
    }
  }

  void showColorPicker(
      BuildContext context,
      StateSetter setSheetState,
      TextEditingController controller) {
    final index = form.teamControllers.indexOf(controller);
    _colorPickerDialogService.showColorPicker(
      context,
      currentColor: form.teamColors[index],
      onColorChanged: (color) {
        setSheetState(() {
          form.teamColors[index] = color;
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
    if (!context.mounted) return;
    await _openRaceSheet(context, masterRace);
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

  @override
  Future<void> loadRaces() async {
    races = await _racesService.loadRaces();
    notifyListeners();
  }

  @override
  void dispose() {
    form.dispose();
    tutorialManager.dispose();
    _eventSubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }
}
