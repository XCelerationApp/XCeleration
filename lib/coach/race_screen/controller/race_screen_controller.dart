import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'race_form_state.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../shared/models/database/team.dart';
import 'package:xceleration/coach/race_screen/screen/race_screen.dart';
import 'package:xceleration/core/utils/sheet_utils.dart' show sheet;
import '../../../core/components/dialog_utils.dart';
import '../../../core/utils/enums.dart' hide EventTypes;
import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/master_race.dart';
import '../../flows/controller/flow_controller.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/services/event_bus.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'package:geolocator/geolocator.dart' show LocationPermission;
import '../../races_screen/controller/races_controller.dart';
import '../services/race_service.dart';
import '../../../core/services/geo_location_service.dart';
import 'package:provider/provider.dart';

/// Controller class for the RaceScreen that handles all business logic
class RaceController with ChangeNotifier {
  // Race data
  bool isRaceSetup = false;
  late TabController tabController;
  final MasterRace masterRace;

  // UI state properties
  bool isLocationButtonVisible = true; // Control visibility of location button

  // Field editing state
  final Set<RaceField> _editingFields = {};
  bool isEditing(RaceField field) => _editingFields.contains(field);

  // Loading states
  bool _isInitialLoading = true; // Only true on first load
  bool _isRefreshing = false; // True during background updates
  String? _error;

  bool get isLoading =>
      _isInitialLoading; // UI only shows spinner on initial load
  bool get isRefreshing => _isRefreshing; // Can show subtle indicator if needed
  bool get hasError => _error != null;
  String get error => _error ?? '';

  // Loaded data - guaranteed non-null when isLoading = false
  Race? _race;
  List<RaceRunner>? _raceRunners;
  List<Team>? _teams;
  bool? _canEdit;

  // Getters for loaded data - guaranteed safe when isLoading = false
  Race get race {
    if (_isInitialLoading) {
      throw StateError('Race data not loaded yet - check isLoading first');
    }
    return _race!;
  }

  List<RaceRunner> get raceRunners {
    if (_isInitialLoading) {
      throw StateError('Race runners not loaded yet - check isLoading first');
    }
    return _raceRunners!;
  }

  List<Team> get teams {
    if (_isInitialLoading) {
      throw StateError('Teams not loaded yet - check isLoading first');
    }
    return _teams!;
  }

  bool get canEdit {
    if (_isInitialLoading) {
      throw StateError('CanEdit not loaded yet - check isLoading first');
    }
    return _canEdit!;
  }

  int get runnersCount => _raceRunners?.length ?? 0;

  // Change tracking
  Map<RaceField, dynamic> originalValues = {};
  Set<RaceField> changedFields = {};
  bool get hasUnsavedChanges => changedFields.isNotEmpty;

  Map<RaceField, TextEditingController> get _fieldControllers => {
        RaceField.name: nameController,
        RaceField.location: locationController,
        RaceField.date: dateController,
        RaceField.distance: distanceController,
        RaceField.unit: unitController,
      };

  // Field edit state management methods
  void startEditingField(RaceField field) {
    _editingFields.add(field);
    notifyListeners();
  }

  void stopEditingField(RaceField field) {
    _editingFields.remove(field);
    notifyListeners();
  }

  // Check if field should be shown as editable (empty during setup or currently being edited)
  bool shouldShowAsEditable(RaceField field) {
    if (!canEdit) return false;
    if (isEditing(field)) return true;
    return switch (field) {
      RaceField.name => race.raceName?.isEmpty ?? true,
      RaceField.location => race.location?.isEmpty ?? true,
      RaceField.date => race.raceDate == null,
      RaceField.distance => race.distance == 0,
      RaceField.unit => false,
    };
  }

  // Change tracking methods
  Future<void> _storeOriginalValue(RaceField field) async {
    final race = await masterRace.race;
    if (!originalValues.containsKey(field)) {
      originalValues[field] = switch (field) {
        RaceField.name => race.raceName ?? '',
        RaceField.location => race.location ?? '',
        RaceField.date => race.raceDate,
        RaceField.distance => race.distance ?? 0,
        RaceField.unit => race.distanceUnit ?? 'mi',
      };
    }
  }

  void trackFieldChange(RaceField field) {
    _storeOriginalValue(field);

    final ctrl = _fieldControllers[field]!;
    final dynamic currentValue = switch (field) {
      RaceField.name => ctrl.text,
      RaceField.location => ctrl.text,
      RaceField.date =>
        ctrl.text.isNotEmpty ? DateTime.tryParse(ctrl.text) : null,
      RaceField.distance => double.tryParse(ctrl.text) ?? 0,
      RaceField.unit => ctrl.text,
    };

    // Check if the current value differs from original
    if (currentValue != originalValues[field]) {
      changedFields.add(field);
    } else {
      changedFields.remove(field);
    }

    notifyListeners();
  }

  // Handle field focus loss with potential autosave
  Future<void> handleFieldFocusLoss(
      BuildContext context, RaceField field) async {
    trackFieldChange(field);

    // Autosave if not in setup flow
    if (!(await _isSetupFlow()) && hasUnsavedChanges && context.mounted) {
      await saveAllChanges(context);
    }
  }

  // Check if currently in setup flow
  Future<bool> _isSetupFlow() async {
    final race = await masterRace.race;
    final flowState = race.flowState;
    return flowState == Race.FLOW_SETUP ||
        flowState == Race.FLOW_SETUP_COMPLETED;
  }

  void revertAllChanges() {
    for (final field in Set<RaceField>.from(changedFields)) {
      _revertField(field);
    }
    changedFields.clear();
    originalValues.clear();
    notifyListeners();
  }

  void _revertField(RaceField field) {
    if (originalValues.containsKey(field)) {
      final value = originalValues[field];
      switch (field) {
        case RaceField.name:
          nameController.text = value ?? '';
        case RaceField.location:
          locationController.text = value ?? '';
        case RaceField.date:
          final date = value as DateTime?;
          dateController.text =
              date != null ? DateFormat('yyyy-MM-dd').format(date) : '';
        case RaceField.distance:
          distanceController.text = (value ?? 0).toString();
        case RaceField.unit:
          unitController.text = value ?? 'mi';
      }
    }
  }

  Future<void> saveAllChanges(BuildContext context) async {
    if (!hasUnsavedChanges) return;

    // Validate all changed fields
    bool allValid = true;
    for (final field in changedFields) {
      switch (field) {
        case RaceField.name:
          nameError = RaceService.validateName(nameController.text);
          if (nameError != null) allValid = false;
        case RaceField.location:
          locationError = RaceService.validateLocation(locationController.text);
          if (locationError != null) allValid = false;
        case RaceField.date:
          dateError = RaceService.validateDate(dateController.text);
          if (dateError != null) allValid = false;
        case RaceField.distance:
          distanceError = RaceService.validateDistance(distanceController.text);
          if (distanceError != null) allValid = false;
        case RaceField.unit:
          break; // no validation needed
      }
    }

    if (!allValid) {
      notifyListeners(); // Update UI to show validation errors
      return;
    }

    // Save the changes
    await saveRaceDetails(context);

    // Clear change tracking and editing state
    changedFields.clear();
    originalValues.clear();
    _editingFields.clear();

    notifyListeners();
  }

  // Navigation state
  bool _showingRunnersManagement = false;
  bool get showingRunnersManagement => _showingRunnersManagement;

  // Runtime state

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

  // Flow state - safe getter that works during loading
  String get flowState {
    if (_isInitialLoading) return 'setup'; // Safe default during loading
    return race.flowState ?? 'setup';
  }

  RacesController parentController;
  final IGeoLocationService _geoLocationService;

  RaceController({
    required this.masterRace,
    required this.parentController,
    IGeoLocationService? geoLocationService,
  }) : _geoLocationService = geoLocationService ?? GeoLocationService();

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
    distanceController.dispose();
    unitController.dispose();
    userlocationController.dispose();
    super.dispose();
  }

  static Future<void> showRaceScreen(BuildContext context,
      RacesController parentController, MasterRace masterRace,
      {RaceScreenPage page = RaceScreenPage.main}) async {
    if (!context.mounted) {
      return;
    }

    try {
      await sheet(
        context: context,
        body: ChangeNotifierProvider(
          create: (context) {
            final controller = RaceController(
              masterRace: masterRace,
              parentController: parentController,
            );
            // Start loading immediately with the context
            WidgetsBinding.instance.addPostFrameCallback((_) {
              controller.loadAllData(context);
            });
            return controller;
          },
          child: RaceScreen(
            masterRace: masterRace,
            parentController: parentController,
            page: page,
          ),
        ),
        takeUpScreen: false, // Allow sheet to size according to content
        showHeader: true, // Keep the handle
      );
    } catch (e, stackTrace) {
      Logger.e('RaceController: showRaceScreen() - Error: $e');
      Logger.e('RaceController: showRaceScreen() - StackTrace: $stackTrace');
      rethrow;
    }

    await parentController.loadRaces();
  }

  /// Load all required data in parallel - for initial load only
  Future<void> loadAllData(BuildContext context) async {
    await _loadData(isInitial: true, context: context);
  }

  /// Core data loading method - handles both initial and background loading
  Future<void> _loadData(
      {required bool isInitial, required BuildContext context}) async {
    try {
      if (isInitial) {
        _isInitialLoading = true;
        _error = null;
      } else {
        _isRefreshing = true;
      }
      notifyListeners();

      // Load all data in parallel
      final results = await Future.wait([
        masterRace.race,
        masterRace.raceRunners,
        masterRace.teams,
      ]);

      _race = results[0] as Race;
      _raceRunners = results[1] as List<RaceRunner>;
      _teams = results[2] as List<Team>;

      // Calculate canEdit based on role and flow state
      final flowState = _race!.flowState;
      final roleAllowsEdit = parentController.canEdit;
      _canEdit = roleAllowsEdit &&
          (flowState == Race.FLOW_SETUP ||
              flowState == Race.FLOW_SETUP_COMPLETED ||
              flowState == Race.FLOW_PRE_RACE);

      if (isInitial) {
        // Only do initialization tasks on first load
        _initializeControllers();
        flowController = MasterFlowController(raceController: this);

        // Set initial flow state if needed
        if ((_race!.flowState == null || _race!.flowState!.isEmpty) &&
            context.mounted) {
          await updateRaceFlowState(context, Race.FLOW_SETUP);
        }

        _isInitialLoading = false;
      } else {
        // Background refresh - just update form controllers if needed
        _updateControllersIfNeeded();
        _isRefreshing = false;
      }

      notifyListeners();
    } catch (e) {
      if (isInitial) {
        _error = e.toString();
        _isInitialLoading = false;
      } else {
        _isRefreshing = false;
        // Don't set error for background refreshes - keep existing data
      }

      notifyListeners();

      if (isInitial) {
        rethrow; // Only rethrow on initial load
      }
    }
  }

  /// Backwards compatibility - calls loadAllData
  Future<void> init(BuildContext context) async {
    return loadAllData(context);
  }

  /// Initialize controllers from race data
  void _initializeControllers() {
    final race = _race!;
    nameController.text = race.raceName ?? '';
    locationController.text = race.location ?? '';
    dateController.text = race.raceDate != null
        ? DateFormat('yyyy-MM-dd').format(race.raceDate!)
        : '';
    distanceController.text = race.distance != null && race.distance! > 0
        ? race.distance.toString()
        : '';
    unitController.text = race.distanceUnit ?? 'mi';
  }

  /// Update controllers only if data has changed (for background refreshes)
  void _updateControllersIfNeeded() {
    final race = _race!;

    // Only update if not currently being edited and value changed
    if (!isEditing(RaceField.name) &&
        nameController.text != (race.raceName ?? '')) {
      nameController.text = race.raceName ?? '';
    }
    if (!isEditing(RaceField.location) &&
        locationController.text != (race.location ?? '')) {
      locationController.text = race.location ?? '';
    }
    if (!isEditing(RaceField.date)) {
      final newDateText = race.raceDate != null
          ? DateFormat('yyyy-MM-dd').format(race.raceDate!)
          : '';
      if (dateController.text != newDateText) {
        dateController.text = newDateText;
      }
    }
    if (!isEditing(RaceField.distance)) {
      final newDistanceText = race.distance != null && race.distance! > 0
          ? race.distance.toString()
          : '';
      if (distanceController.text != newDistanceText) {
        distanceController.text = newDistanceText;
      }
    }
    // Unit is less likely to be edited, always update
    if (unitController.text != (race.distanceUnit ?? 'mi')) {
      unitController.text = race.distanceUnit ?? 'mi';
    }
  }

  Future<void> saveRaceDetails(BuildContext context) async {
    await RaceService.saveRaceDetails(
      masterRace: masterRace,
      nameController: nameController,
      locationController: locationController,
      dateController: dateController,
      distanceController: distanceController,
      unitController: unitController,
    );
    // Refresh the race data
    await loadRace();
    notifyListeners();
    final setupComplete = await RaceService.checkSetupComplete(
      masterRace: masterRace,
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
  Future<bool> saveFieldIfValid(BuildContext context, RaceField field) async {
    // Validate the specific field first
    bool isValid = true;
    switch (field) {
      case RaceField.name:
        nameError = RaceService.validateName(nameController.text);
        isValid = nameError == null;
      case RaceField.location:
        locationError = RaceService.validateLocation(locationController.text);
        isValid = locationError == null;
      case RaceField.date:
        dateError = RaceService.validateDate(dateController.text);
        isValid = dateError == null;
      case RaceField.distance:
        distanceError = RaceService.validateDistance(distanceController.text);
        isValid = distanceError == null;
      case RaceField.unit:
        isValid = true;
    }

    if (!isValid) {
      notifyListeners(); // Update UI to show validation errors
      return false;
    }

    // Save the changes
    await saveRaceDetails(context);

    // Stop editing this field
    stopEditingField(field);

    return true;
  }

  /// Load the race data and any saved results
  Future<void> loadRace() async {
    final loadedRace = await masterRace.race;

    // Populate controllers with race data
    nameController.text = loadedRace.raceName ?? '';
    locationController.text = loadedRace.location ?? '';
    if (loadedRace.raceDate != null) {
      dateController.text =
          DateFormat('yyyy-MM-dd').format(loadedRace.raceDate!);
    }
    distanceController.text = loadedRace.distance.toString();
    unitController.text = loadedRace.distanceUnit ?? 'mi';
  }

  /// Update the race flow state
  Future<void> updateRaceFlowState(
      BuildContext context, String newState) async {
    final race = await masterRace.race;
    String previousState = race.flowState ?? '';

    final updatedRace = race.copyWith(flowState: newState);
    await masterRace.updateRace(updatedRace);
    notifyListeners();

    // Show setup completion dialog if transitioning from setup to setup-completed
    if (previousState == Race.FLOW_SETUP &&
        newState == Race.FLOW_SETUP_COMPLETED) {
      Future.delayed(Duration.zero, () {
        if (context.mounted) {
          DialogUtils.showMessageDialog(context,
              title: 'Setup Complete',
              message:
                  'You completed setting up your race!\n\nBefore race day, make sure you have two assistants with this app installed on their phones to help time the race.\nBegin the Sharing Race step once you are at the race with your assistants.',
              doneText: 'Got it');
        }
      });
    }

    // Publish an event when race flow state changes
    EventBus.instance.fire(EventTypes.raceFlowStateChanged, {
      'raceId': masterRace.raceId,
      'newState': newState,
      'race': updatedRace,
    });
  }

  /// Mark the current flow as completed
  Future<void> markCurrentFlowCompleted(BuildContext context) async {
    final race = await masterRace.race;
    if (!context.mounted) return;

    // Update to the completed state for the current flow
    String completedState = race.completedFlowState;
    await updateRaceFlowState(context, completedState);

    // Check if the context is still mounted before using ScaffoldMessenger
    if (!context.mounted) return;
  }

  /// Begin the next flow in the sequence
  Future<void> beginNextFlow(BuildContext context) async {
    final race = await masterRace.race;
    if (!context.mounted) return;

    // Determine the next non-completed flow state
    String nextState = race.nextFlowState;

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
    final race = await masterRace.race;
    if (!context.mounted) return;

    String currentState = race.flowState!;

    // Handle setup state differently - don't treat it as a flow
    if (currentState == Race.FLOW_SETUP) {
      // Just check if we can advance to setup_complete
      final canAdvance = await RaceService.checkSetupComplete(
          masterRace: masterRace,
          nameController: nameController,
          locationController: locationController,
          dateController: dateController,
          distanceController: distanceController);

      if (!canAdvance) {
        return;
      }

      // Check if context is still mounted after async operation
      if (!context.mounted) return;

      // Actually advance to the next state
      await updateRaceFlowState(context, Race.FLOW_SETUP_COMPLETED);
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
    // race is updated in the async operation, so we need to get the latest race
    final currentRace = await masterRace.race;
    if (!context.mounted) return;
    await flowController.handleFlowNavigation(context, currentRace.flowState!);
  }

  /// Navigate to runners management screen with confirmation if needed
  Future<void> loadRunnersManagementScreenWithConfirmation(BuildContext context,
      {bool isViewMode = false}) async {
    // Check if we need to show confirmation dialog only when user can edit
    final canEditValue = canEdit;
    if (canEditValue &&
        !isViewMode &&
        await _shouldShowRunnersEditConfirmation() &&
        context.mounted) {
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
  Future<void> navigateToRaceDetails(BuildContext context) async {
    _showingRunnersManagement = false;

    // Refresh race data to get updated team information
    await refreshRaceData(context);

    notifyListeners();
  }

  /// Refresh race data from database
  Future<void> refreshRaceData(BuildContext context) async {
    if (!context.mounted) return;

    // Invalidate the cache to force fresh data from database
    masterRace.invalidateCache();

    // Reload all data
    await _loadData(isInitial: false, context: context);
  }

  /// Check if we should show confirmation dialog before editing runners
  Future<bool> _shouldShowRunnersEditConfirmation() async {
    final race = await masterRace.race;

    // Show confirmation only if runners have already been shared with assistants
    final flowState = race.flowState;
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
      LocationPermission permission =
          await _geoLocationService.checkPermission();
      if (!context.mounted) return; // Check if context is still valid

      if (permission == LocationPermission.denied) {
        permission = await _geoLocationService.requestPermission();
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
      DialogUtils.showErrorDialog(context, message: 'Could not get location');
    }
  }

  void updateLocationButtonVisibility() {
    isLocationButtonVisible =
        locationController.text.trim() != userlocationController.text.trim();
    notifyListeners();
  }
}

