import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:geocoding/geocoding.dart';
import 'package:xceleration/coach/race_screen/screen/race_screen.dart';
import 'package:xceleration/core/utils/sheet_utils.dart' show sheet;
import '../../../core/components/dialog_utils.dart';
import '../../../core/utils/enums.dart' hide EventTypes;
import '../../../core/utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../flows/controller/flow_controller.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/services/event_bus.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'package:geolocator/geolocator.dart'; // Import for geolocation
import '../../races_screen/controller/races_controller.dart';
import '../services/race_service.dart';
import 'package:provider/provider.dart';

/// Controller class for the RaceScreen that handles all business logic
class RaceController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  late TabController tabController;

  // UI state properties
  bool isLocationButtonVisible = true; // Control visibility of location button

  // Individual field edit states
  bool isEditingName = false;
  bool isEditingLocation = false;
  bool isEditingDate = false;
  bool isEditingDistance = false;

  // Change tracking
  Map<String, dynamic> originalValues = {};
  Set<String> changedFields = {};
  bool get hasUnsavedChanges => changedFields.isNotEmpty;

  // Permission system - determines if user can edit fields
  bool get canEdit {
    if (race == null) return true; // Allow editing during initial setup
    final flowState = race!.flowState;
    // Allow editing during setup and setup completed states
    return flowState == Race.FLOW_SETUP ||
        flowState == Race.FLOW_SETUP_COMPLETED ||
        flowState == Race.FLOW_PRE_RACE;
  }

  // Field edit state management methods
  void startEditingField(String fieldName) {
    switch (fieldName) {
      case 'name':
        isEditingName = true;
        break;
      case 'location':
        isEditingLocation = true;
        break;
      case 'date':
        isEditingDate = true;
        break;
      case 'distance':
        isEditingDistance = true;
        break;
    }
    notifyListeners();
  }

  void stopEditingField(String fieldName) {
    switch (fieldName) {
      case 'name':
        isEditingName = false;
        break;
      case 'location':
        isEditingLocation = false;
        break;
      case 'date':
        isEditingDate = false;
        break;
      case 'distance':
        isEditingDistance = false;
        break;
    }
    notifyListeners();
  }

  // Check if field should be shown as editable (empty during setup or currently being edited)
  bool shouldShowAsEditable(String fieldName) {
    if (!canEdit) return false;

    // Always show as editable if currently being edited
    switch (fieldName) {
      case 'name':
        return isEditingName || (race?.raceName.isEmpty ?? true);
      case 'location':
        return isEditingLocation || (race?.location.isEmpty ?? true);
      case 'date':
        return isEditingDate || (race?.raceDate == null);
      case 'distance':
        return isEditingDistance || (race?.distance == 0);
      default:
        return false;
    }
  }

  // Change tracking methods
  void _storeOriginalValue(String fieldName) {
    if (!originalValues.containsKey(fieldName)) {
      switch (fieldName) {
        case 'name':
          originalValues[fieldName] = race?.raceName ?? '';
          break;
        case 'location':
          originalValues[fieldName] = race?.location ?? '';
          break;
        case 'date':
          originalValues[fieldName] = race?.raceDate;
          break;
        case 'distance':
          originalValues[fieldName] = race?.distance ?? 0;
          break;
        case 'unit':
          originalValues[fieldName] = race?.distanceUnit ?? 'mi';
          break;
      }
    }
  }

  void trackFieldChange(String fieldName) {
    _storeOriginalValue(fieldName);

    dynamic currentValue;
    switch (fieldName) {
      case 'name':
        currentValue = nameController.text;
        break;
      case 'location':
        currentValue = locationController.text;
        break;
      case 'date':
        currentValue = dateController.text.isNotEmpty
            ? DateTime.tryParse(dateController.text)
            : null;
        break;
      case 'distance':
        currentValue = double.tryParse(distanceController.text) ?? 0;
        break;
      case 'unit':
        currentValue = unitController.text;
        break;
    }

    // Check if the current value differs from original
    if (currentValue != originalValues[fieldName]) {
      changedFields.add(fieldName);
    } else {
      changedFields.remove(fieldName);
    }

    notifyListeners();
  }

  // Handle field focus loss with potential autosave
  Future<void> handleFieldFocusLoss(
      BuildContext context, String fieldName) async {
    trackFieldChange(fieldName);

    // Autosave if not in setup flow
    if (!_isSetupFlow() && hasUnsavedChanges) {
      await saveAllChanges(context);
    }
  }

  // Check if currently in setup flow
  bool _isSetupFlow() {
    final flowState = race?.flowState;
    return flowState == Race.FLOW_SETUP ||
        flowState == Race.FLOW_SETUP_COMPLETED;
  }

  void revertAllChanges() {
    for (String fieldName in Set<String>.from(changedFields)) {
      _revertField(fieldName);
    }
    changedFields.clear();
    originalValues.clear();
    notifyListeners();
  }

  void _revertField(String fieldName) {
    if (originalValues.containsKey(fieldName)) {
      switch (fieldName) {
        case 'name':
          nameController.text = originalValues[fieldName] ?? '';
          break;
        case 'location':
          locationController.text = originalValues[fieldName] ?? '';
          break;
        case 'date':
          final date = originalValues[fieldName] as DateTime?;
          dateController.text =
              date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
          break;
        case 'distance':
          distanceController.text = (originalValues[fieldName] ?? 0).toString();
          break;
        case 'unit':
          unitController.text = originalValues[fieldName] ?? 'mi';
          break;
      }
    }
  }

  Future<void> saveAllChanges(BuildContext context) async {
    if (!hasUnsavedChanges) return;

    // Validate all changed fields
    bool allValid = true;
    for (String fieldName in changedFields) {
      switch (fieldName) {
        case 'name':
          nameError = RaceService.validateName(nameController.text);
          if (nameError != null) allValid = false;
          break;
        case 'location':
          locationError = RaceService.validateLocation(locationController.text);
          if (locationError != null) allValid = false;
          break;
        case 'date':
          dateError = RaceService.validateDate(dateController.text);
          if (dateError != null) allValid = false;
          break;
        case 'distance':
          distanceError = RaceService.validateDistance(distanceController.text);
          if (distanceError != null) allValid = false;
          break;
      }
    }

    if (!allValid) {
      notifyListeners(); // Update UI to show validation errors
      return;
    }

    // Save the changes
    await saveRaceDetails(context);

    // Clear change tracking
    changedFields.clear();
    originalValues.clear();

    // Stop editing all fields
    isEditingName = false;
    isEditingLocation = false;
    isEditingDate = false;
    isEditingDistance = false;

    notifyListeners();
  }

  // Navigation state
  bool _showingRunnersManagement = false;
  bool get showingRunnersManagement => _showingRunnersManagement;

  // Runtime state
  int runnersCount = 0;

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController userlocationController = TextEditingController();

  // Validation error messages
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;

  late MasterFlowController flowController;

  // Flow state
  String get flowState => race?.flowState ?? 'setup';

  RacesController parentController;

  RaceController({
    required this.raceId,
    required this.parentController,
  });

  static Future<void> showRaceScreen(
      BuildContext context, RacesController parentController, int raceId,
      {RaceScreenPage page = RaceScreenPage.main}) async {
    if (!context.mounted) return;

    await sheet(
      context: context,
      body: ChangeNotifierProvider(
        create: (_) => RaceController(
          raceId: raceId,
          parentController: parentController,
        ),
        child: RaceScreen(
          raceId: raceId,
          parentController: parentController,
          page: page,
        ),
      ),
      takeUpScreen: false, // Allow sheet to size according to content
      showHeader: true, // Keep the handle
    );
    await parentController.loadRaces();
  }

  Future<void> init(BuildContext context) async {
    race = await loadRace();

    // Check if context is still mounted after loading race
    if (!context.mounted) return;

    _initializeControllers();
    flowController = MasterFlowController(raceController: this);
    loadRunnersCount();

    // Set initial flow state to setup if it's a new race
    if (race != null && race!.flowState.isEmpty) {
      await updateRaceFlowState(context, Race.FLOW_SETUP);

      // Check if context is still mounted after updating race flow state
      if (!context.mounted) return;
    }

    notifyListeners();
  }

  /// Initialize controllers from race data
  void _initializeControllers() {
    if (race != null) {
      nameController.text = race!.raceName;
      locationController.text = race!.location;
      dateController.text = race!.raceDate != null
          ? DateFormat('yyyy-MM-dd').format(race!.raceDate!)
          : '';
      distanceController.text =
          race!.distance > 0 ? race!.distance.toString() : '';
      unitController.text = race!.distanceUnit;
      // Teams are now managed by RunnersManagementController
    }
  }

  Future<void> saveRaceDetails(BuildContext context) async {
    await RaceService.saveRaceDetails(
      raceId: raceId,
      nameController: nameController,
      locationController: locationController,
      dateController: dateController,
      distanceController: distanceController,
      unitController: unitController,
    );
    // Refresh the race data
    race = await loadRace();
    notifyListeners();
    // Check if we can move to setup_complete
    final setupComplete = await RaceService.checkSetupComplete(
      race: race,
      raceId: raceId,
      nameController: nameController,
      locationController: locationController,
      dateController: dateController,
      distanceController: distanceController,
    );
    if (setupComplete && context.mounted) {
      await updateRaceFlowState(context, Race.FLOW_SETUP_COMPLETED);
    }
  }

  // Individual field save methods with validation
  Future<bool> saveFieldIfValid(BuildContext context, String fieldName) async {
    // Validate the specific field first
    bool isValid = true;
    switch (fieldName) {
      case 'name':
        nameError = RaceService.validateName(nameController.text);
        isValid = nameError == null;
        break;
      case 'location':
        locationError = RaceService.validateLocation(locationController.text);
        isValid = locationError == null;
        break;
      case 'date':
        dateError = RaceService.validateDate(dateController.text);
        isValid = dateError == null;
        break;
      case 'distance':
        distanceError = RaceService.validateDistance(distanceController.text);
        isValid = distanceError == null;
        break;
    }

    if (!isValid) {
      notifyListeners(); // Update UI to show validation errors
      return false;
    }

    // Save the changes
    await saveRaceDetails(context);

    // Stop editing this field
    stopEditingField(fieldName);

    return true;
  }

  /// Load the race data and any saved results
  Future<Race?> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);

    // Populate controllers with race data
    if (loadedRace != null) {
      nameController.text = loadedRace.raceName;
      locationController.text = loadedRace.location;
      if (loadedRace.raceDate != null) {
        dateController.text =
            DateFormat('yyyy-MM-dd').format(loadedRace.raceDate!);
      }
      distanceController.text = loadedRace.distance.toString();
      unitController.text = loadedRace.distanceUnit;
    }

    return loadedRace;
  }

  /// Load race data without overwriting form controllers (preserves unsaved changes)
  Future<Race?> loadRaceDataOnly() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
    return loadedRace;
  }

  /// Update the race flow state
  Future<void> updateRaceFlowState(
      BuildContext context, String newState) async {
    if (!context.mounted) {
      Logger.d('Context not mounted - attempting to use navigator context');
    }
    final navigatorContext = Navigator.of(context);
    String previousState = race?.flowState ?? '';
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    race = race?.copyWith(flowState: newState);
    notifyListeners();

    // Show setup completion dialog if transitioning from setup to setup-completed
    if (previousState == Race.FLOW_SETUP &&
        newState == Race.FLOW_SETUP_COMPLETED) {
      // Need to use a delay to ensure context is ready after state updates
      Future.delayed(Duration.zero, () {
        if (!context.mounted) context = navigatorContext.context;
        if (context.mounted) {
          DialogUtils.showMessageDialog(context,
              title: 'Setup Complete',
              message:
                  'You completed setting up your race!\n\nBefore race day, make sure you have two assistants with this app installed on their phones to help time the race.\nBegin the Sharing Runners step once you are at the race with your assistants.',
              doneText: 'Got it');
        } else {
          Logger.d('Context not mounted');
        }
      });
    }

    // Publish an event when race flow state changes
    EventBus.instance.fire(EventTypes.raceFlowStateChanged, {
      'raceId': raceId,
      'newState': newState,
      'race': race,
    });
  }

  /// Mark the current flow as completed
  Future<void> markCurrentFlowCompleted(BuildContext context) async {
    if (race == null) return;

    // Update to the completed state for the current flow
    String completedState = race!.completedFlowState;
    await updateRaceFlowState(context, completedState);

    // Check if the context is still mounted before using ScaffoldMessenger
    if (!context.mounted) return;
  }

  /// Begin the next flow in the sequence
  Future<void> beginNextFlow(BuildContext context) async {
    if (race == null) return;

    // Determine the next non-completed flow state
    String nextState = race!.nextFlowState;

    // If the next state is a completed state, skip to the one after that
    if (nextState.contains(Race.FLOW_COMPLETED_SUFFIX)) {
      int nextIndex = Race.FLOW_SEQUENCE.indexOf(nextState) + 1;
      if (nextIndex < Race.FLOW_SEQUENCE.length) {
        nextState = Race.FLOW_SEQUENCE[nextIndex];
      }
    }

    // Update to the next flow state
    await updateRaceFlowState(context, nextState);

    // Check if context is still valid after the async operation
    if (!context.mounted) return;

    // Navigate to the appropriate screen based on the flow
    await flowController.handleFlowNavigation(context, nextState);

    // We should ideally add another context.mounted check here, but since this is
    // the last statement and we're not using the context after this, we'll leave it
    // to the flowController to handle context checking internally
  }

  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow(BuildContext context) async {
    if (race == null) return;

    String currentState = race!.flowState;

    // Handle setup state differently - don't treat it as a flow
    if (currentState == Race.FLOW_SETUP) {
      // Just check if we can advance to setup_complete
      final canAdvance = await RaceService.checkSetupComplete(
          race: race!,
          raceId: raceId,
          nameController: nameController,
          locationController: locationController,
          dateController: dateController,
          distanceController: distanceController);

      if (!canAdvance) {
        return;
      }

      // Check if context is still mounted after async operation
      if (!context.mounted) return;
      return;
    }

    // If the current state is a completed state, move to the next non-completed state
    if (currentState.contains(Race.FLOW_COMPLETED_SUFFIX)) {
      String nextState;

      if (currentState == Race.FLOW_SETUP_COMPLETED) {
        nextState = Race.FLOW_PRE_RACE;
      } else if (currentState == Race.FLOW_PRE_RACE_COMPLETED) {
        nextState = Race.FLOW_POST_RACE;
        // } else if (currentState == Race.FLOW_POST_RACE_COMPLETED) {
        //   nextState = Race.FLOW_FINISHED;
      } else {
        return; // Unknown completed state
      }

      // Update to the next flow state
      await updateRaceFlowState(context, nextState);

      // Check if context is still mounted after async operation
      if (!context.mounted) return;
    }

    // Check if context is still valid before navigation
    if (!context.mounted) return;

    // Use the flow controller to handle the navigation
    await flowController.handleFlowNavigation(context, race!.flowState);
  }

  /// Navigate to runners management screen with confirmation if needed
  Future<void> loadRunnersManagementScreenWithConfirmation(BuildContext context,
      {bool isViewMode = false}) async {
    // Check if we need to show confirmation dialog only when user can edit
    if (canEdit && !isViewMode && _shouldShowRunnersEditConfirmation()) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Edit Runners',
        content:
            'You have already shared runners with your assistants. If you make changes, you will need to reshare the updated runner list.\n\nDo you want to continue?',
        confirmText: 'Continue',
        cancelText: 'Cancel',
      );

      if (!confirmed) return;
    }

    // Navigate to runners management screen
    navigateToRunnersManagement(isViewMode: isViewMode);
  }

  /// Navigate to runners management screen
  void navigateToRunnersManagement({bool isViewMode = false}) {
    _showingRunnersManagement = true;
    notifyListeners();
  }

  /// Navigate back to race details
  Future<void> navigateToRaceDetails() async {
    _showingRunnersManagement = false;

    // Refresh race data to get updated team information
    await refreshRaceData();

    notifyListeners();
  }

  /// Refresh race data from database
  Future<void> refreshRaceData() async {
    final previousTeamCount = race?.teams.length ?? 0;
    race = await loadRaceDataOnly();
    await loadRunnersCount();
    final newTeamCount = race?.teams.length ?? 0;

    Logger.d(
        'Race data refreshed: $previousTeamCount -> $newTeamCount teams, $runnersCount runners');
    notifyListeners();
  }

  /// Check if we should show confirmation dialog before editing runners
  bool _shouldShowRunnersEditConfirmation() {
    if (race == null) return false;

    // Show confirmation only if runners have already been shared with assistants
    final flowState = race!.flowState;
    return flowState == Race.FLOW_PRE_RACE_COMPLETED ||
        flowState == Race.FLOW_POST_RACE;
  }

  // OLD SHEET-BASED IMPLEMENTATION - NO LONGER NEEDED
  // The runners management screen is now integrated directly into the race screen

  // Validation methods for form fields
  void validateName(String name, StateSetter setSheetState) {
    setSheetState(() {
      nameError = RaceService.validateName(name);
    });
  }

  void validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      locationError = RaceService.validateLocation(location);
    });
  }

  void validateDate(String dateString, StateSetter setSheetState) {
    final error = RaceService.validateDate(dateString);
    setSheetState(() {
      dateError = error;
    });
  }

  void validateDistance(String distanceString, StateSetter setSheetState) {
    final error = RaceService.validateDistance(distanceString);
    setSheetState(() {
      distanceError = error;
    });
  }

  // Date picker method
  Future<void> selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      notifyListeners();
    }
  }

  /// Create device connections list for communication
  DevicesManager createDevices(DeviceType deviceType,
      {DeviceName deviceName = DeviceName.coach, String data = ''}) {
    return DeviceConnectionService.createDevices(
      deviceName,
      deviceType,
      data: data,
    );
  }

  /// Get the current location
  Future<void> getCurrentLocation(BuildContext context) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (!context.mounted) return; // Check if context is still valid

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!context.mounted) {
          return; // Check if context is still valid after async request
        }
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

  void updateLocationButtonVisibility() {
    isLocationButtonVisible =
        locationController.text.trim() != userlocationController.text.trim();
    notifyListeners();
  }

  /// Load runners count for this race
  Future<void> loadRunnersCount() async {
    if (race != null) {
      final runners =
          await DatabaseHelper.instance.getRaceRunners(race!.raceId);
      runnersCount = runners.length;
      notifyListeners();
    }
  }
}

// Global key for navigator context in dialogs
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
