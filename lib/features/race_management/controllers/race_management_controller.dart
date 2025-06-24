import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/event_bus.dart';
import '../../../shared/constants/app_constants.dart' as constants;
import '../models/race_model.dart';
import '../services/race_service.dart';

/// Consolidated controller for all race management operations
/// Replaces RacesController, RaceController, and FlowController
class RaceManagementController extends ChangeNotifier {
  final RaceService _raceService;
  final EventBus _eventBus;

  // State
  List<RaceModel> _races = [];
  RaceModel? _selectedRace;
  bool _isLoading = false;
  String? _errorMessage;

  // Form controllers for race creation/editing
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController distanceController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final List<TextEditingController> teamControllers = [];
  final List<Color> teamColors = [];

  // Validation state
  String? nameError;
  String? locationError;
  String? dateError;
  String? distanceError;
  String? teamsError;

  // Filters and sorting
  String _searchQuery = '';
  String _filterFlowState = '';
  RaceSortOption _sortOption = RaceSortOption.dateNewest;

  RaceManagementController({
    RaceService? raceService,
    EventBus? eventBus,
  })  : _raceService = raceService ?? RaceService(),
        _eventBus = eventBus ?? EventBus.instance {
    _initializeEventListeners();
    loadRaces();
  }

  // Getters
  List<RaceModel> get races => _filteredAndSortedRaces;
  List<RaceModel> get allRaces => List.unmodifiable(_races);
  RaceModel? get selectedRace => _selectedRace;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get filterFlowState => _filterFlowState;
  RaceSortOption get sortOption => _sortOption;

  /// Get filtered and sorted races based on current criteria
  List<RaceModel> get _filteredAndSortedRaces {
    var filtered = _races.where((race) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!race.raceName.toLowerCase().contains(query) &&
            !race.location.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Flow state filter
      if (_filterFlowState.isNotEmpty && race.flowState != _filterFlowState) {
        return false;
      }

      return true;
    }).toList();

    // Sort races
    switch (_sortOption) {
      case RaceSortOption.nameAZ:
        filtered.sort((a, b) => a.raceName.compareTo(b.raceName));
        break;
      case RaceSortOption.nameZA:
        filtered.sort((a, b) => b.raceName.compareTo(a.raceName));
        break;
      case RaceSortOption.dateNewest:
        filtered.sort((a, b) {
          if (a.raceDate == null && b.raceDate == null) return 0;
          if (a.raceDate == null) return 1;
          if (b.raceDate == null) return -1;
          return b.raceDate!.compareTo(a.raceDate!);
        });
        break;
      case RaceSortOption.dateOldest:
        filtered.sort((a, b) {
          if (a.raceDate == null && b.raceDate == null) return 0;
          if (a.raceDate == null) return 1;
          if (b.raceDate == null) return -1;
          return a.raceDate!.compareTo(b.raceDate!);
        });
        break;
      case RaceSortOption.flowState:
        filtered.sort((a, b) => a.flowState.compareTo(b.flowState));
        break;
    }

    return filtered;
  }

  /// Initialize event listeners
  void _initializeEventListeners() {
    _eventBus.on(constants.EventTypes.raceCreated, (_) => loadRaces());
    _eventBus.on(constants.EventTypes.raceUpdated, (_) => loadRaces());
    _eventBus.on(constants.EventTypes.raceDeleted, (_) => loadRaces());
    _eventBus.on(constants.EventTypes.raceFlowStateChanged, (_) => loadRaces());
  }

  /// RACE LIST OPERATIONS

  /// Load all races
  Future<void> loadRaces() async {
    try {
      _setLoading(true);
      _clearError();

      final races = await _raceService.getAllRaces();
      _races = races;

      Logger.d('Loaded ${races.length} races');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load races: $e');
      Logger.e('Error loading races', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set flow state filter
  void setFlowStateFilter(String flowState) {
    _filterFlowState = flowState;
    notifyListeners();
  }

  /// Set sort option
  void setSortOption(RaceSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _filterFlowState = '';
    _sortOption = RaceSortOption.dateNewest;
    notifyListeners();
  }

  /// INDIVIDUAL RACE OPERATIONS

  /// Select a race for detailed operations
  Future<void> selectRace(int raceId) async {
    try {
      _setLoading(true);
      _clearError();

      final race = await _raceService.getRaceById(raceId);
      _selectedRace = race;

      if (race != null) {
        _populateFormControllers(race);
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load race details: $e');
      Logger.e('Error selecting race', error: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Clear race selection
  void clearSelection() {
    _selectedRace = null;
    _clearFormControllers();
    notifyListeners();
  }

  /// Create a new race
  Future<int?> createRace() async {
    if (!_validateForm()) return null;

    try {
      _setLoading(true);
      _clearError();

      final race = _buildRaceFromForm();
      final raceId = await _raceService.createRace(race);

      Logger.d('Created race with ID: $raceId');
      _clearFormControllers();

      return raceId;
    } catch (e) {
      _setError('Failed to create race: $e');
      Logger.e('Error creating race', error: e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update the selected race
  Future<bool> updateRace() async {
    if (_selectedRace == null || !_validateForm()) return false;

    try {
      _setLoading(true);
      _clearError();

      final updatedRace = _buildRaceFromForm(existingRace: _selectedRace!);
      await _raceService.updateRace(updatedRace);
      _selectedRace = updatedRace;

      Logger.d('Updated race: ${updatedRace.raceId}');
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update race: $e');
      Logger.e('Error updating race', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a race
  Future<bool> deleteRace(int raceId) async {
    try {
      _setLoading(true);
      _clearError();

      await _raceService.deleteRace(raceId);

      // Clear selection if deleted race was selected
      if (_selectedRace?.raceId == raceId) {
        clearSelection();
      }

      Logger.d('Deleted race: $raceId');
      return true;
    } catch (e) {
      _setError('Failed to delete race: $e');
      Logger.e('Error deleting race', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// FLOW MANAGEMENT

  /// Advance race to next flow state
  Future<bool> advanceRaceFlow(int raceId) async {
    final race = _races.firstWhereOrNull((r) => r.raceId == raceId);
    if (race == null) return false;

    final nextState = race.nextFlowState;
    if (nextState == null) return false;

    try {
      _setLoading(true);
      _clearError();

      await _raceService.updateRaceFlowState(raceId, nextState);

      Logger.d('Advanced race $raceId to flow state: $nextState');
      return true;
    } catch (e) {
      _setError('Failed to advance race flow: $e');
      Logger.e('Error advancing race flow', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update race flow state manually
  Future<bool> updateRaceFlowState(int raceId, String newState) async {
    try {
      _setLoading(true);
      _clearError();

      await _raceService.updateRaceFlowState(raceId, newState);

      Logger.d('Updated race $raceId flow state to: $newState');
      return true;
    } catch (e) {
      _setError('Failed to update race flow state: $e');
      Logger.e('Error updating race flow state', error: e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// TEAM MANAGEMENT

  /// Add a new team field
  void addTeamField() {
    teamControllers.add(TextEditingController());
    teamColors.add(_generateTeamColor(teamControllers.length - 1));
    notifyListeners();
  }

  /// Remove a team field
  void removeTeamField(int index) {
    if (index < teamControllers.length) {
      teamControllers[index].dispose();
      teamControllers.removeAt(index);
      if (index < teamColors.length) {
        teamColors.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// Generate a color for a team based on index
  Color _generateTeamColor(int index) {
    final hue = (360 / 8 * index) % 360; // 8 distinct colors
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  /// FORM MANAGEMENT

  /// Populate form controllers from race data
  void _populateFormControllers(RaceModel race) {
    nameController.text = race.raceName;
    locationController.text = race.location;
    dateController.text = race.raceDate?.toIso8601String().split('T')[0] ?? '';
    distanceController.text = race.distance > 0 ? race.distance.toString() : '';
    unitController.text = race.distanceUnit;

    // Clear existing team controllers
    for (final controller in teamControllers) {
      controller.dispose();
    }
    teamControllers.clear();
    teamColors.clear();

    // Add team controllers
    for (int i = 0; i < race.teams.length; i++) {
      final controller = TextEditingController(text: race.teams[i]);
      teamControllers.add(controller);

      if (i < race.teamColors.length) {
        teamColors.add(race.teamColors[i]);
      } else {
        teamColors.add(_generateTeamColor(i));
      }
    }

    // Ensure at least one team field
    if (teamControllers.isEmpty) {
      addTeamField();
    }
  }

  /// Clear all form controllers
  void _clearFormControllers() {
    nameController.clear();
    locationController.clear();
    dateController.clear();
    distanceController.clear();
    unitController.text = 'mi';

    for (final controller in teamControllers) {
      controller.dispose();
    }
    teamControllers.clear();
    teamColors.clear();

    _clearValidationErrors();
  }

  /// Build race model from form data
  RaceModel _buildRaceFromForm({RaceModel? existingRace}) {
    final teams = teamControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    return RaceModel(
      raceId: existingRace?.raceId ?? 0,
      raceName: nameController.text.trim(),
      location: locationController.text.trim(),
      raceDate: dateController.text.isNotEmpty
          ? DateTime.tryParse(dateController.text)
          : null,
      distance: double.tryParse(distanceController.text) ?? 0.0,
      distanceUnit: unitController.text.trim(),
      teams: teams,
      teamColors: teamColors.take(teams.length).toList(),
      flowState: existingRace?.flowState ?? RaceModel.FLOW_SETUP,
      runners: existingRace?.runners ?? [],
      statistics: existingRace?.statistics ?? const RaceStatistics(),
    );
  }

  /// VALIDATION

  /// Validate form data
  bool _validateForm() {
    _clearValidationErrors();
    bool isValid = true;

    // Validate name
    nameError = RaceService.validateRaceName(nameController.text);
    if (nameError != null) isValid = false;

    // Validate location
    locationError = RaceService.validateLocation(locationController.text);
    if (locationError != null) isValid = false;

    // Validate date
    dateError = RaceService.validateDate(dateController.text);
    if (dateError != null) isValid = false;

    // Validate distance
    distanceError = RaceService.validateDistance(distanceController.text);
    if (distanceError != null) isValid = false;

    // Validate teams
    final nonEmptyTeams = teamControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (nonEmptyTeams.isEmpty) {
      teamsError = 'At least one team is required';
      isValid = false;
    }

    notifyListeners();
    return isValid;
  }

  /// Clear validation errors
  void _clearValidationErrors() {
    nameError = null;
    locationError = null;
    dateError = null;
    distanceError = null;
    teamsError = null;
  }

  /// UTILITY METHODS

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _clearError();
    notifyListeners();
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear error message
  void _clearError() {
    _errorMessage = null;
  }

  /// Get races by flow state
  List<RaceModel> getRacesByFlowState(String flowState) {
    return _races.where((race) => race.flowState == flowState).toList();
  }

  /// Get active races (not finished)
  List<RaceModel> getActiveRaces() {
    return _races
        .where((race) => race.flowState != RaceModel.FLOW_FINISHED)
        .toList();
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
    distanceController.dispose();
    unitController.dispose();

    for (final controller in teamControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}

/// Enum for race sorting options
enum RaceSortOption {
  nameAZ('Name A-Z'),
  nameZA('Name Z-A'),
  dateNewest('Date (Newest)'),
  dateOldest('Date (Oldest)'),
  flowState('Flow State');

  const RaceSortOption(this.displayName);
  final String displayName;
}
