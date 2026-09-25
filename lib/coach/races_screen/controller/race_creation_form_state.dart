import 'package:flutter/material.dart';

/// Owns all form state for the race creation sheet:
/// TextEditingControllers, team lists, error notifiers, and validation.
///
/// Mirrors the [RaceFormState] pattern used in the race edit screen.
class RaceCreationFormState extends ChangeNotifier {
  // TextEditingControllers — owned and disposed here
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController userLocationController = TextEditingController();

  // Team state
  final List<TextEditingController> teamControllers = [];
  final List<Color> teamColors = [];

  // Per-field error notifiers — each field widget listens only to its own notifier
  final nameErrorNotifier = ValueNotifier<String?>(null);
  final locationErrorNotifier = ValueNotifier<String?>(null);
  final dateErrorNotifier = ValueNotifier<String?>(null);
  final distanceErrorNotifier = ValueNotifier<String?>(null);
  final locationButtonVisibleNotifier = ValueNotifier<bool>(true);

  // Convenience getters/setters
  String? get nameError => nameErrorNotifier.value;
  set nameError(String? v) => nameErrorNotifier.value = v;
  String? get locationError => locationErrorNotifier.value;
  set locationError(String? v) => locationErrorNotifier.value = v;
  String? get dateError => dateErrorNotifier.value;
  set dateError(String? v) => dateErrorNotifier.value = v;
  String? get distanceError => distanceErrorNotifier.value;
  set distanceError(String? v) => distanceErrorNotifier.value = v;
  bool get isLocationButtonVisible => locationButtonVisibleNotifier.value;
  set isLocationButtonVisible(bool v) => locationButtonVisibleNotifier.value = v;

  RaceCreationFormState() {
    _initTeams();
  }

  void _initTeams() {
    teamControllers.add(TextEditingController());
    teamControllers.add(TextEditingController());
    teamColors.add(Colors.white);
    teamColors.add(Colors.white);
    unitController.text = 'mi';
  }

  void addTeamField() {
    teamControllers.add(TextEditingController());
    teamColors.add(Colors.white);
    notifyListeners();
  }

  void updateLocationButtonVisibility() {
    locationButtonVisibleNotifier.value =
        locationController.text.trim() != userLocationController.text.trim();
  }

  void reset() {
    nameController.text = '';
    locationController.text = '';
    dateController.text = '';
    distanceController.text = '';
    userLocationController.text = '';
    isLocationButtonVisible = true;
    for (final c in teamControllers) {
      c.dispose();
    }
    teamControllers.clear();
    teamControllers.add(TextEditingController());
    teamControllers.add(TextEditingController());
    teamColors.clear();
    teamColors.add(Colors.white);
    teamColors.add(Colors.white);
    unitController.text = 'mi';
    nameErrorNotifier.value = null;
    locationErrorNotifier.value = null;
    dateErrorNotifier.value = null;
    distanceErrorNotifier.value = null;
    locationButtonVisibleNotifier.value = true;
    notifyListeners();
  }

  bool validateRaceName() {
    if (nameController.text.trim().isEmpty) {
      nameErrorNotifier.value = 'Race name is required';
      return false;
    }
    nameErrorNotifier.value = null;
    return true;
  }

  bool validateRaceCreation() => validateRaceName();

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
    distanceController.dispose();
    unitController.dispose();
    userLocationController.dispose();
    for (final c in teamControllers) {
      c.dispose();
    }
    teamColors.clear();
    nameErrorNotifier.dispose();
    locationErrorNotifier.dispose();
    dateErrorNotifier.dispose();
    distanceErrorNotifier.dispose();
    locationButtonVisibleNotifier.dispose();
    super.dispose();
  }
}
