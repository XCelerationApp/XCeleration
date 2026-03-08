import 'package:flutter/material.dart';
import 'race_form_state.dart';
import 'race_geo_controller.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../shared/models/database/team.dart';
import '../../../core/utils/enums.dart' hide EventTypes;
import '../../../shared/models/database/race.dart';
import '../../../shared/models/database/master_race.dart';
import '../../flows/controller/flow_controller.dart';
import '../../../core/services/device_connection_factory_impl.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/services/event_bus.dart';
import '../../../core/services/i_device_connection_factory.dart';
import 'package:intl/intl.dart';
import '../../races_screen/controller/i_parent_race_controller.dart';
import '../services/race_service.dart';
import '../../../core/services/geo_location_service.dart';
import '../../../core/services/date_picker_service.dart';
import '../../../core/components/dialog_utils.dart';

// RaceController coordinates data loading, form save orchestration, and
// navigation state. These concerns share the MasterRace dependency tightly
// enough that further decomposition would introduce circular dependencies.
// The class is intentionally slightly over 300 lines as a justified exception.
class RaceController with ChangeNotifier {
  // Race data
  bool isRaceSetup = false;
  late TabController tabController;
  final MasterRace masterRace;

  // Form state — owns TextEditingControllers, errors, editing state, change tracking
  final RaceFormState form = RaceFormState();

  // Loading states
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  String? _error;

  bool get isLoading => _isInitialLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasError => _error != null;
  String get error => _error ?? '';

  // Loaded data — guaranteed non-null when isLoading = false
  Race? _race;
  List<RaceRunner>? _raceRunners;
  List<Team>? _teams;
  bool? _canEdit;

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

  /// Safe nullable accessor — does not throw during initial load.
  List<Team>? get teamsOrNull => _teams;

  // Change tracking delegated to form
  void trackFieldChange(RaceField field) {
    if (_race != null) {
      form.storeOriginalValue(field, _race!);
    }
    form.trackChange(field);
  }

  // Navigation state
  bool _showingRunnersManagement = false;
  bool get showingRunnersManagement => _showingRunnersManagement;

  late final MasterFlowController flowController;

  // Flow state — safe getter that works during loading
  String get flowState {
    if (_isInitialLoading) return 'setup';
    return race.flowState ?? 'setup';
  }

  IParentRaceController parentController;
  final IDatePickerService _datePickerService;
  final IEventBus _eventBus;
  final IDeviceConnectionFactory _devicesFactory;

  late final RaceGeoController _geoController;

  RaceController({
    required this.masterRace,
    required this.parentController,
    IGeoLocationService? geoLocationService,
    IDatePickerService? datePickerService,
    MasterFlowController? flowController,
    IEventBus? eventBus,
    IDeviceConnectionFactory? devicesFactory,
    RaceGeoController? geoController,
  })  : _datePickerService = datePickerService ?? DatePickerService(),
        _eventBus = eventBus ?? EventBus.instance,
        _devicesFactory = devicesFactory ?? const DeviceConnectionFactoryImpl() {
    this.flowController =
        flowController ?? MasterFlowController(raceController: this);
    _geoController = geoController ??
        RaceGeoController(
          geoLocationService: geoLocationService ?? GeoLocationService(),
          form: form,
        );
    _geoController.addListener(notifyListeners);
    form.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _geoController.removeListener(notifyListeners);
    _geoController.dispose();
    form.removeListener(notifyListeners);
    form.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading

  /// Load all required data in parallel — for initial load only.
  Future<void> loadAllData(BuildContext context) async {
    await _loadData(isInitial: true, context: context);
  }

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

      final results = await Future.wait([
        masterRace.race,
        masterRace.raceRunners,
        masterRace.teams,
      ]);

      _race = results[0] as Race;
      _raceRunners = results[1] as List<RaceRunner>;
      _teams = results[2] as List<Team>;

      final flowState = _race!.flowState;
      final roleAllowsEdit = parentController.canEdit;
      _canEdit = roleAllowsEdit &&
          (flowState == Race.FLOW_SETUP ||
              flowState == Race.FLOW_SETUP_COMPLETED ||
              flowState == Race.FLOW_PRE_RACE);

      if (isInitial) {
        form.initializeFrom(_race!);

        if ((_race!.flowState == null || _race!.flowState!.isEmpty) &&
            context.mounted) {
          await updateRaceFlowState(context, Race.FLOW_SETUP);
        }

        _isInitialLoading = false;
      } else {
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
      }

      notifyListeners();

      if (isInitial) rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Save orchestration

  Future<void> saveRaceDetails(BuildContext context) async {
    await RaceService.saveRaceDetails(
      masterRace: masterRace,
      nameController: form.nameController,
      locationController: form.locationController,
      dateController: form.dateController,
      distanceController: form.distanceController,
      unitController: form.unitController,
    );
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

  Future<void> handleFieldFocusLoss(
      BuildContext context, RaceField field) async {
    trackFieldChange(field);
    if (!(await _isSetupFlow()) && form.hasUnsavedChanges && context.mounted) {
      await saveAllChanges(context);
    }
  }

  Future<bool> _isSetupFlow() async {
    final race = await masterRace.race;
    final flowState = race.flowState;
    return flowState == Race.FLOW_SETUP ||
        flowState == Race.FLOW_SETUP_COMPLETED;
  }

  Future<void> saveAllChanges(BuildContext context) async {
    if (!form.hasUnsavedChanges) return;

    bool allValid = true;
    for (final field in form.changedFields) {
      form.applyValidation(field);
      if (form.errorFor(field) != null) allValid = false;
    }

    if (!allValid) return;

    await saveRaceDetails(context);
    form.clearChangeTracking();
  }

  Future<bool> saveFieldIfValid(BuildContext context, RaceField field) async {
    form.applyValidation(field);

    if (form.errorFor(field) != null) return false;

    await saveRaceDetails(context);
    form.stopEditing(field);
    return true;
  }

  Future<void> loadRace() async {
    final loadedRace = await masterRace.race;
    form.initializeFrom(loadedRace);
  }

  // ---------------------------------------------------------------------------
  // Flow state — low-level persistence (orchestration lives in MasterFlowController)

  /// Updates the race flow state in the database, notifies listeners, and
  /// fires the raceFlowStateChanged event.
  Future<void> updateRaceFlowState(
      BuildContext context, String newState) async {
    final race = await masterRace.race;
    final String previousState = race.flowState ?? '';

    final updatedRace = race.copyWith(flowState: newState);
    await masterRace.updateRace(updatedRace);
    notifyListeners();

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

    _eventBus.fire(EventTypes.raceFlowStateChanged, {
      'raceId': masterRace.raceId,
      'newState': newState,
      'race': updatedRace,
    });
  }

  // ---------------------------------------------------------------------------
  // Flow orchestration — delegates to MasterFlowController

  Future<void> continueRaceFlow(BuildContext context) =>
      flowController.continueRaceFlow(context);

  Future<void> markCurrentFlowCompleted(BuildContext context) =>
      flowController.markCurrentFlowCompleted(context);

  Future<void> beginNextFlow(BuildContext context) =>
      flowController.beginNextFlow(context);

  // ---------------------------------------------------------------------------
  // Navigation

  Future<void> loadRunnersManagementScreenWithConfirmation(BuildContext context,
      {bool isViewMode = false}) async {
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

    navigateToRunnersManagement(isViewMode: isViewMode);
  }

  void navigateToRunnersManagement({bool isViewMode = false}) {
    _showingRunnersManagement = true;
    notifyListeners();
  }

  Future<void> navigateToRaceDetails(BuildContext context) async {
    _showingRunnersManagement = false;
    await refreshRaceData(context);
    notifyListeners();
  }

  Future<void> refreshRaceData(BuildContext context) async {
    if (!context.mounted) return;
    masterRace.invalidateCache();
    await _loadData(isInitial: false, context: context);
  }

  Future<bool> _shouldShowRunnersEditConfirmation() async {
    final race = await masterRace.race;
    final flowState = race.flowState;
    return flowState == Race.FLOW_PRE_RACE_COMPLETED ||
        flowState == Race.FLOW_POST_RACE;
  }

  // ---------------------------------------------------------------------------
  // Validation — thin delegations to RaceFormState

  void validateName(String name) => form.validateName(name);
  void validateLocation(String location) => form.validateLocation(location);
  void validateDate(String dateString) => form.validateDate(dateString);
  void validateDistance(String distanceString) =>
      form.validateDistance(distanceString);

  // ---------------------------------------------------------------------------
  // Date picker

  Future<void> selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await _datePickerService.pickDate(
      context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      form.dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Devices

  DevicesManager createDevices(DeviceType deviceType,
      {DeviceName deviceName = DeviceName.coach, String data = ''}) {
    return _devicesFactory.createDevices(
      deviceName,
      deviceType,
      data: data,
    );
  }

  // ---------------------------------------------------------------------------
  // Geolocation — delegates to RaceGeoController

  bool get isLocationButtonVisible => _geoController.isLocationButtonVisible;

  Future<void> getCurrentLocation(BuildContext context) =>
      _geoController.getCurrentLocation(context);

  void updateLocationButtonVisibility() =>
      _geoController.updateLocationButtonVisibility();
}
