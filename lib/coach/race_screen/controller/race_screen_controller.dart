import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:geocoding/geocoding.dart';
import 'package:xceleration/coach/race_screen/screen/race_screen.dart';
import 'package:xceleration/coach/runners_management_screen/screen/runners_management_screen.dart';
import 'package:xceleration/core/components/button_components.dart';
import 'package:xceleration/utils/sheet_utils.dart' show sheet;
import '../../../core/components/dialog_utils.dart';
import '../../../utils/enums.dart';
import '../../../utils/database_helper.dart';
import '../../../shared/models/race.dart';
import '../../flows/controller/flow_controller.dart';
import '../../../core/services/device_connection_service.dart';
import '../../../core/services/event_bus.dart';
import 'package:intl/intl.dart'; // Import the intl package for date formatting
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Import for color picker
import 'package:geolocator/geolocator.dart'; // Import for geolocation
import '../../races_screen/controller/races_controller.dart';

/// Controller class for the RaceScreen that handles all business logic
class RaceController with ChangeNotifier {
  // Race data
  Race? race;
  int raceId;
  bool isRaceSetup = false;
  late TabController tabController;
  
  // UI state properties
  bool isLocationButtonVisible = true; // Control visibility of location button
  
  // Runtime state
  int runnersCount = 0;
  
  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController userlocationController = TextEditingController();
  
  // Team management
  List<TextEditingController> teamControllers = [];
  List<Color> teamColors = [];
  String? teamsError;
  
  // Validation error messages
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;

  late MasterFlowController flowController;

  // Flow state
  String get flowState => race?.flowState ?? 'setup';

  BuildContext? _context;

  RacesController parentController;
  
  RaceController({required this.raceId, required this.parentController});

  void setContext(BuildContext context) {
    _context = context;
  }

  BuildContext get context {
    assert(_context != null,
        'Context not set in RaceController. Call setContext() first.');
    return _context!;
  }

  static Future<void> showRaceScreen(BuildContext context, RacesController parentController, int raceId,
      {RaceScreenPage page = RaceScreenPage.main}) async {
    await sheet(
      context: context,
      body: RaceScreen(
        raceId: raceId,
        parentController: parentController,
        page: page,
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
      distanceController.text = race!.distance > 0 ? race!.distance.toString() : '';
      unitController.text = race!.distanceUnit;
      _initializeTeamControllers();
    }
  }

  /// Initialize team controllers from race data
  void _initializeTeamControllers() {
    if (race != null) {
      teamControllers.clear();
      teamColors.clear();
      
      // If no teams exist yet, add one empty controller
      if (race!.teams.isEmpty) {
        teamControllers.add(TextEditingController());
        teamColors.add(Colors.white); // Default first team color
      } else {
        // Create controllers for each team
        for (var i = 0; i < race!.teams.length; i++) {
          var controller = TextEditingController(text: race!.teams[i]);
          teamControllers.add(controller);
          
          // Use the color from race.teamColors if available
          if (i < race!.teamColors.length) {
            teamColors.add(race!.teamColors[i]);
          } else {
            // Create a new color based on index
            teamColors.add(HSLColor.fromAHSL(1.0, (360 / race!.teams.length * i) % 360, 0.7, 0.5).toColor());
          }
        }
      }
    }
  }

  /// Add a new team field
  void addTeamField() {
    teamControllers.add(TextEditingController());
    
    teamColors.add(Colors.white);
    notifyListeners();
  }

  Future<void> saveRaceDetails(BuildContext context) async {    
    // Capture the context in a local variable before any async operations
    
    // Parse date
    DateTime? date;
    try {
      if (dateController.text.isNotEmpty) {
        date = DateTime.parse(dateController.text);
      }
    } catch (e) {
      SnackBar(content: Text('Invalid date format. Use YYYY-MM-DD'));
      return;
    }
    
    // Parse distance - use 0 as sentinel value for empty/unset
    double distance = 0; // Default to sentinel value
    try {
      if (distanceController.text.isNotEmpty) {
        final parsedDistance = double.parse(distanceController.text);
        // Only store positive values, otherwise keep as 0 sentinel
        distance = parsedDistance > 0 ? parsedDistance : 0;
      }
    } catch (e) {
      SnackBar(content: Text('Invalid distance format'));
      return;
    }
    
    // Update the race in database
    await DatabaseHelper.instance.updateRaceField(raceId, 'location', locationController.text);
    await DatabaseHelper.instance.updateRaceField(raceId, 'raceDate', date?.toIso8601String());
    await DatabaseHelper.instance.updateRaceField(raceId, 'distance', distance);
    await DatabaseHelper.instance.updateRaceField(raceId, 'distanceUnit', unitController.text);
    
    await saveTeamData();
    
    // Refresh the race data
    race = await loadRace();
    notifyListeners();
    
    // Check if we can move to setup_complete
    await checkSetupComplete();
  }

  /// Check if all requirements are met to advance to setup_complete
  Future<bool> checkSetupComplete() async {
    if (race?.flowState != Race.FLOW_SETUP) return false;
    
    // Check for minimum runners
    final hasMinimumRunners = await RunnersManagementScreen.checkMinimumRunnersLoaded(raceId);
    
    // Check if essential race fields are filled
    final fieldsComplete = 
        nameController.text.isNotEmpty &&
        locationController.text.isNotEmpty &&
        dateController.text.isNotEmpty &&
        distanceController.text.isNotEmpty &&
        teamControllers.where((controller) => controller.text.isNotEmpty).isNotEmpty;
    
    // If all requirements are met, advance to setup_complete
    if (hasMinimumRunners && fieldsComplete) {
      // Check if context is still mounted before using it
      if (!context.mounted) return false;
      
      await updateRaceFlowState(context, Race.FLOW_SETUP_COMPLETED);
      // Check if the context is still mounted after the async operation
      if (!context.mounted) return false;
      return true;
    }
    
    return false;
  }

  /// Save team data to database
  Future<void> saveTeamData() async {
    if (race == null) return;
    
    final teams = teamControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    
    // Convert Color objects to integer values for database storage
    final colors = teamColors.map((color) => color.toARGB32()).toList();
    
    await DatabaseHelper.instance.updateRaceField(race!.raceId, 'teams', teams);
    await DatabaseHelper.instance.updateRaceField(race!.raceId, 'teamColors', colors);
  }

  /// Show color picker dialog for team color
  void showColorPicker(StateSetter setSheetState, TextEditingController teamController) {
    final index = teamControllers.indexOf(teamController);
    if (index < 0) return;

    Color pickerColor = teamColors[index];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color for this team'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setSheetState(() {
                  teamColors[index] = pickerColor;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  /// Load the race data and any saved results
  Future<Race?> loadRace() async {
    final loadedRace = await DatabaseHelper.instance.getRaceById(raceId);
    
    // Populate controllers with race data
    if (loadedRace != null) {
      nameController.text = loadedRace.raceName;
      locationController.text = loadedRace.location;
      if (loadedRace.raceDate != null) {
        dateController.text = DateFormat('yyyy-MM-dd').format(loadedRace.raceDate!);
      }
      distanceController.text = loadedRace.distance.toString();
      unitController.text = loadedRace.distanceUnit;
    }
    
    return loadedRace;
  }

  /// Update the race flow state
  Future<void> updateRaceFlowState(BuildContext? context, String newState) async {
    String previousState = race?.flowState ?? '';
    await DatabaseHelper.instance.updateRaceFlowState(raceId, newState);
    race = race?.copyWith(flowState: newState);
    notifyListeners();
    
    // Show setup completion dialog if transitioning from setup to setup-completed
    if (previousState == Race.FLOW_SETUP && newState == Race.FLOW_SETUP_COMPLETED) {
      // Need to use a delay to ensure context is ready after state updates
      Future.delayed(Duration.zero, () {
        if (context != null && context.mounted) {
          DialogUtils.showMessageDialog(context, 
            title: 'Setup Complete', 
            message: 'You completed setting up your race!\n\nBefore race day, make sure you have two assistants with this app installed on their phones to help time the race.\nBegin the Sharing Runners step once you are at the race with your assistants.', 
            doneText: 'Got it'
          );
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
    
    // Show a confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_getFlowDisplayName(race!.flowState)} completed!'))
    );
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
    
    // If the race is now finished, show a final success message
    if (nextState == Race.FLOW_FINISHED) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Race has been completed! All steps are finished.'))
      );
    } else {
      // Otherwise show which flow we're beginning
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beginning ${_getFlowDisplayName(nextState)}'))
      );
    }
    
    // Navigate to the appropriate screen based on the flow
    await flowController.handleFlowNavigation(context, nextState);
    
    // We should ideally add another context.mounted check here, but since this is
    // the last statement and we're not using the context after this, we'll leave it
    // to the flowController to handle context checking internally
  }
  
  /// Helper method to get a user-friendly name for a flow state
  String _getFlowDisplayName(String flowState) {
    if (flowState == Race.FLOW_SETUP || flowState == Race.FLOW_SETUP_COMPLETED) {
      return 'Setup';
    }
    if (flowState == Race.FLOW_PRE_RACE || flowState == Race.FLOW_PRE_RACE_COMPLETED) {
      return 'Pre-Race';
    }
    if (flowState == Race.FLOW_POST_RACE) {
      return 'Post-Race';
    }
    if (flowState == Race.FLOW_FINISHED) {
      return 'Race';
    }
    return flowState.replaceAll('-', ' ').split(' ').map((s) => s.isEmpty ? '' : '${s[0].toUpperCase()}${s.substring(1)}').join(' ');
  }

  /// Continue the race flow based on the current state
  Future<void> continueRaceFlow(BuildContext context) async {
    if (race == null) return;
    
    String currentState = race!.flowState;
    
    // Handle setup state differently - don't treat it as a flow
    if (currentState == Race.FLOW_SETUP) {
      // Just check if we can advance to setup_complete
      final canAdvance = await checkSetupComplete();
      
      // Check if context is still mounted after async operation
      if (!context.mounted) return;
      
      if (!canAdvance) {
        // Show message about missing requirements
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete race details and load runners before continuing'))
        );
      }
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
      
      // Show a message about which flow we're starting
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Beginning ${_getFlowDisplayName(nextState)}'))
      );
    }
    
    // Check if context is still valid before navigation
    if (!context.mounted) return;
    
    // Use the flow controller to handle the navigation
    await flowController.handleFlowNavigation(context, race!.flowState);
  }

  /// Load runners management screen
  void loadRunnersManagementScreen(BuildContext context) {
    sheet(
      context: context,
      takeUpScreen: true,
      title: 'Load Runners',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: RunnersManagementScreen(
              raceId: raceId,
              showHeader: false,
              onContentChanged: () async {
                // Refresh race data when runners are changed
                race = await loadRace();
                notifyListeners();
              },
            ),
          ),
          const SizedBox(height: 16),
          FullWidthButton(
            text: 'Done',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
      showHeader: true,
    );
  }

  // Validation methods for form fields
  void validateName(String name, StateSetter setSheetState) {
    setSheetState(() {
      nameError = name.isEmpty ? 'Please enter a race name' : null;
    });
  }

  void validateLocation(String location, StateSetter setSheetState) {
    setSheetState(() {
      locationError = location.isEmpty ? 'Please enter a location' : null;
    });
  }

  void validateDate(String dateString, StateSetter setSheetState) {
    if (dateString.isEmpty) {
      setSheetState(() {
        dateError = 'Please enter a date';
      });
      return;
    }

    try {
      // Just parse to validate format, no need to store the result
      DateFormat('yyyy-MM-dd').parseStrict(dateString);
      setSheetState(() {
        dateError = null;
      });
    } catch (e) {
      setSheetState(() {
        dateError = 'Please enter a valid date (YYYY-MM-DD)';
      });
    }
  }

  void validateDistance(String distanceString, StateSetter setSheetState) {
    if (distanceString.isEmpty) {
      setSheetState(() {
        distanceError = 'Please enter a distance';
      });
      return;
    }

    try {
      final distance = double.parse(distanceString);
      if (distance <= 0) {
        setSheetState(() {
          distanceError = 'Distance must be greater than 0';
          // Reset negative values to empty string to prevent -1 from being displayed
          if (distance < 0) {
            distanceController.text = '';
          }
        });
      } else {
        setSheetState(() {
          distanceError = null;
        });
      }
    } catch (e) {
      setSheetState(() {
        distanceError = 'Please enter a valid number';
        // Reset invalid values to empty string
        distanceController.text = '';
      });
    }
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
  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (!context.mounted) return; // Check if context is still valid
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!context.mounted) return; // Check if context is still valid after async request
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
      Logger.d('Error getting location: $e');      DialogUtils.showErrorDialog(context, message: 'Could not get location');
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
      final runners = await DatabaseHelper.instance.getRaceRunners(race!.raceId);
      runnersCount = runners.length;
      notifyListeners();
    }
  }
}

// Global key for navigator context in dialogs
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
