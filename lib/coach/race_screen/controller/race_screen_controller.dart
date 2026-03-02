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

  // Form state — owns TextEditingControllers, errors, editing state, change tracking
  final RaceFormState form = RaceFormState();

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

  // Change tracking delegated to form
  void trackFieldChange(RaceField field) {
    if (_race != null) {
      form.storeOriginalValue(field, _race!);
    }
    form.trackChange(field);
    // form.trackChange calls notifyListeners on form → relayed to controller via listener
  }

  // Navigation state
  bool _showingRunnersManagement = false;
  bool get showingRunnersManagement => _showingRunnersManagement;

  late final MasterFlowController flowController;

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
    MasterFlowController? flowController,
  }) : _geoLocationService = geoLocationService ?? GeoLocationService() {
    this.flowController =
        flowController ?? MasterFlowController(raceController: this);
    form.addListener(notifyListeners);
  }

  @override
  void dispose() {
    form.removeListener(notifyListeners);
    form.dispose();
    super.dispose();
  }

  // TODO(refactor): static factory couples callers to RaceController directly.
  // Fix: move to a router, presenter, or factory class. Controller should not know how to show itself.
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
        form.initializeFrom(_race!);

        // Set initial flow state if needed
        if ((_race!.flowState == null || _race!.flowState!.isEmpty) &&
            context.mounted) {
          await updateRaceFlowState(context, Race.FLOW_SETUP);
        }

        _isInitialLoading = false;
      } else {
        // Background refresh - just update form controllers if needed
        form.updateFrom(_race!);
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
  // TODO(refactor): backwards-compat shim — remove once all callers use loadAllData() directly.
  Future<void> init(BuildContext context) async {
    return loadAllData(context);
  }

  Future<void> saveRaceDetails(BuildContext context) async {
    await RaceService.saveRaceDetails(
      masterRace: masterRace,
      nameController: form.nameController,
      locationController: form.locationController,
      dateController: form.dateController,
      distanceController: form.distanceController,
      unitController: form.unitController,
    );
    // Refresh the race data
    await loadRace();
    notifyListeners();
    final setupComplete = await RaceService.checkSetupComplete(
      masterRace: masterRace,
      nameController: form.nameController,
      locationController: form.locationController,
      dateController: form.dateController,
      distanceController: form.distanceController,
    );
    if (setupComplete && context.mounted) {
      await updateRaceFlowState(context, Race.FLOW_SETUP_COMPLETED);
    }
  }

  // Handle field focus loss with potential autosave
  Future<void> handleFieldFocusLoss(
      BuildContext context, RaceField field) async {
    trackFieldChange(field);

    // Autosave if not in setup flow
    if (!(await _isSetupFlow()) && form.hasUnsavedChanges && context.mounted) {
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

  Future<void> saveAllChanges(BuildContext context) async {
    if (!form.hasUnsavedChanges) return;

    // Validate all changed fields
    bool allValid = true;
    for (final field in form.changedFields) {
      switch (field) {
        case RaceField.name:
          form.setError(
              RaceField.name, RaceService.validateName(form.nameController.text));
          if (form.errorFor(RaceField.name) != null) allValid = false;
        case RaceField.location:
          form.setError(RaceField.location,
              RaceService.validateLocation(form.locationController.text));
          if (form.errorFor(RaceField.location) != null) allValid = false;
        case RaceField.date:
          form.setError(
              RaceField.date, RaceService.validateDate(form.dateController.text));
          if (form.errorFor(RaceField.date) != null) allValid = false;
        case RaceField.distance:
          form.setError(RaceField.distance,
              RaceService.validateDistance(form.distanceController.text));
          if (form.errorFor(RaceField.distance) != null) allValid = false;
        case RaceField.unit:
          break; // no validation needed
      }
    }

    if (!allValid) {
      // form.setError already triggered notifyListeners
      return;
    }

    // Save the changes
    await saveRaceDetails(context);

    // Clear change tracking, original values, and editing state
    form.clearChangeTracking();
  }

  // Individual field save methods with validation
  Future<bool> saveFieldIfValid(BuildContext context, RaceField field) async {
    // Validate the specific field first
    bool isValid = true;
    switch (field) {
      case RaceField.name:
        form.setError(
            RaceField.name, RaceService.validateName(form.nameController.text));
        isValid = form.errorFor(RaceField.name) == null;
      case RaceField.location:
        form.setError(RaceField.location,
            RaceService.validateLocation(form.locationController.text));
        isValid = form.errorFor(RaceField.location) == null;
      case RaceField.date:
        form.setError(
            RaceField.date, RaceService.validateDate(form.dateController.text));
        isValid = form.errorFor(RaceField.date) == null;
      case RaceField.distance:
        form.setError(RaceField.distance,
            RaceService.validateDistance(form.distanceController.text));
        isValid = form.errorFor(RaceField.distance) == null;
      case RaceField.unit:
        isValid = true;
    }

    if (!isValid) {
      // form.setError already triggered notifyListeners
      return false;
    }

    // Save the changes
    await saveRaceDetails(context);

    // Stop editing this field
    form.stopEditing(field);

    return true;
  }

  /// Load the race data and any saved results
  Future<void> loadRace() async {
    final loadedRace = await masterRace.race;
    form.initializeFrom(loadedRace);
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
          nameController: form.nameController,
          locationController: form.locationController,
          dateController: form.dateController,
          distanceController: form.distanceController);

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

  // Validation methods for form fields (used by races_screen widgets via StateSetter)
  // TODO(refactor): StateSetter coupling — controllers must not call widget state setters.
  // Fix: remove StateSetter parameter. Callers should call form.setError(RaceField.name, msg)
  // then call setState themselves. Requires updating all widget call sites.
  void validateName(String name, StateSetter setSheetState) {
    setSheetState(() {
      form.setError(RaceField.name, RaceService.validateName(name));
    });
  }

  // TODO(refactor): StateSetter coupling — controllers must not call widget state setters.
  // Fix: remove StateSetter parameter. Callers should call form.setError(RaceField.location, msg)
  // then call setState themselves. Requires updating all widget call sites.
  void validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      form.setError(
          RaceField.location, RaceService.validateLocation(location));
    });
  }

  // TODO(refactor): StateSetter coupling — controllers must not call widget state setters.
  // Fix: remove StateSetter parameter. Callers should call form.setError(RaceField.date, msg)
  // then call setState themselves. Requires updating all widget call sites.
  void validateDate(String dateString, StateSetter setSheetState) {
    setSheetState(() {
      form.setError(RaceField.date, RaceService.validateDate(dateString));
    });
  }

  // TODO(refactor): StateSetter coupling — controllers must not call widget state setters.
  // Fix: remove StateSetter parameter. Callers should call form.setError(RaceField.distance, msg)
  // then call setState themselves. Requires updating all widget call sites.
  void validateDistance(String distanceString, StateSetter setSheetState) {
    setSheetState(() {
      form.setError(
          RaceField.distance, RaceService.validateDistance(distanceString));
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
      form.dateController.text = DateFormat('yyyy-MM-dd').format(picked);
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
      form.locationController.text =
          '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
      form.userLocationController.text = form.locationController.text;
      form.setError(RaceField.location, null);
      updateLocationButtonVisibility();
    } catch (e) {
      Logger.d('Error getting location: $e');
      DialogUtils.showErrorDialog(context, message: 'Could not get location');
    }
  }

  void updateLocationButtonVisibility() {
    isLocationButtonVisible = form.locationController.text.trim() !=
        form.userLocationController.text.trim();
    notifyListeners();
  }
}
