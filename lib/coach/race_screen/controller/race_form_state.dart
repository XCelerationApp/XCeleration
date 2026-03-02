import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/database/race.dart';

enum RaceField { name, location, date, distance, unit }

/// Owns all form state for the race edit screen:
/// TextEditingControllers, validation errors, editing state, and change tracking.
class RaceFormState extends ChangeNotifier {
  // TextEditingControllers — owned and disposed here
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController userLocationController = TextEditingController();

  // Validation errors per field
  final Map<RaceField, String?> _errors = {};
  String? errorFor(RaceField field) => _errors[field];

  void setError(RaceField field, String? error) {
    _errors[field] = error;
    notifyListeners();
  }

  // Editing state
  final Set<RaceField> _editingFields = {};
  bool isEditing(RaceField field) => _editingFields.contains(field);

  void startEditing(RaceField field) {
    _editingFields.add(field);
    notifyListeners();
  }

  void stopEditing(RaceField field) {
    _editingFields.remove(field);
    notifyListeners();
  }

  // Change tracking
  final Map<RaceField, dynamic> _originalValues = {};
  final Set<RaceField> _changedFields = {};
  bool get hasUnsavedChanges => _changedFields.isNotEmpty;
  Set<RaceField> get changedFields => Set.unmodifiable(_changedFields);

  TextEditingController controllerFor(RaceField field) => switch (field) {
        RaceField.name => nameController,
        RaceField.location => locationController,
        RaceField.date => dateController,
        RaceField.distance => distanceController,
        RaceField.unit => unitController,
      };

  void storeOriginalValue(RaceField field, Race race) {
    if (!_originalValues.containsKey(field)) {
      _originalValues[field] = switch (field) {
        RaceField.name => race.raceName ?? '',
        RaceField.location => race.location ?? '',
        RaceField.date => race.raceDate,
        RaceField.distance => race.distance ?? 0,
        RaceField.unit => race.distanceUnit ?? 'mi',
      };
    }
  }

  void trackChange(RaceField field) {
    final ctrl = controllerFor(field);
    final dynamic currentValue = switch (field) {
      RaceField.name => ctrl.text,
      RaceField.location => ctrl.text,
      RaceField.date =>
        ctrl.text.isNotEmpty ? DateTime.tryParse(ctrl.text) : null,
      RaceField.distance => double.tryParse(ctrl.text) ?? 0,
      RaceField.unit => ctrl.text,
    };

    if (currentValue != _originalValues[field]) {
      _changedFields.add(field);
    } else {
      _changedFields.remove(field);
    }
    notifyListeners();
  }

  void revertField(RaceField field) {
    if (_originalValues.containsKey(field)) {
      final value = _originalValues[field];
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

  void revertAll() {
    for (final field in Set<RaceField>.from(_changedFields)) {
      revertField(field);
    }
    _changedFields.clear();
    _originalValues.clear();
    notifyListeners();
  }

  /// Clears change tracking, original values, and editing state.
  void clearChangeTracking() {
    _changedFields.clear();
    _originalValues.clear();
    _editingFields.clear();
    notifyListeners();
  }

  bool shouldShowAsEditable(RaceField field, Race race, bool canEdit) {
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

  void initializeFrom(Race race) {
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

  void updateFrom(Race race) {
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
    if (unitController.text != (race.distanceUnit ?? 'mi')) {
      unitController.text = race.distanceUnit ?? 'mi';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
    distanceController.dispose();
    unitController.dispose();
    userLocationController.dispose();
    super.dispose();
  }
}
