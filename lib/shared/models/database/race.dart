// ignore_for_file: constant_identifier_names, non_constant_identifier_names

class Race {
  final int? raceId;
  final String? uuid;
  final String? raceName;
  final DateTime? raceDate;
  final String? location;
  final double? distance;
  final String? distanceUnit;
  final String? flowState;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? isDirty;

  // Flow state static constants
  static const String FLOW_SETUP = 'setup';
  static const String FLOW_SETUP_COMPLETED = 'setup-completed';
  static const String FLOW_PRE_RACE = 'pre-race';
  static const String FLOW_PRE_RACE_COMPLETED = 'pre-race-completed';
  static const String FLOW_POST_RACE = 'post-race';
  static const String FLOW_FINISHED = 'finished';

  // Suffix for completed states
  static const String FLOW_COMPLETED_SUFFIX = '-completed';

  // Flow sequence for progression
  static const List<String> FLOW_SEQUENCE = [
    FLOW_SETUP,
    FLOW_SETUP_COMPLETED,
    FLOW_PRE_RACE,
    FLOW_PRE_RACE_COMPLETED,
    FLOW_POST_RACE,
    FLOW_FINISHED
  ];

  Race({
    this.raceId,
    this.uuid,
    this.raceName,
    this.raceDate,
    this.location,
    this.distance,
    this.distanceUnit,
    this.flowState,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.isDirty,
  });

  // Create a Race from JSON
  static Race fromJson(Map<String, dynamic> race) {
    return Race(
      raceId: int.parse(race['race_id'].toString()),
      uuid: race['uuid'],
      raceName: race['name'],
      raceDate:
          race['race_date'] != null ? DateTime.parse(race['race_date']) : null,
      location: race['location'] ?? '',
      distance: race['distance'] != null
          ? double.parse(race['distance'].toString())
          : 0.0,
      distanceUnit: race['distance_unit'] ?? 'mi',
      flowState: race['flow_state'] ?? FLOW_SETUP,
      createdAt: race['created_at'] != null
          ? DateTime.parse(race['created_at'])
          : null,
      updatedAt: race['updated_at'] != null
          ? DateTime.parse(race['updated_at'])
          : null,
      deletedAt: race['deleted_at'] != null
          ? DateTime.parse(race['deleted_at'])
          : null,
      isDirty: race['is_dirty'],
    );
  }

  // Convert a Race into a Map
  Map<String, dynamic> toMap() {
    final map = {
      'name': raceName,
      'race_date': raceDate?.toIso8601String(),
      'location': location,
      'distance': distance,
      'distance_unit': distanceUnit,
      'flow_state': flowState,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_dirty': isDirty,
    };

    return map;
  }

  // Create a copy of Race with some fields replaced
  Race copyWith({
    int? raceId,
    String? uuid,
    String? raceName,
    DateTime? raceDate,
    String? location,
    double? distance,
    String? distanceUnit,
    String? flowState,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? isDirty,
  }) {
    return Race(
      raceId: raceId ?? this.raceId,
      uuid: uuid ?? this.uuid,
      raceName: raceName ?? this.raceName,
      raceDate: raceDate ?? this.raceDate,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      flowState: flowState ?? this.flowState,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  // Returns true if the current flow state is a completed state
  bool get isCurrentFlowCompleted {
    if (flowState == null) return false;
    return flowState!.contains(FLOW_COMPLETED_SUFFIX) ||
        flowState == FLOW_FINISHED;
  }

  // Returns the current flow name without the '-completed' suffix
  String get currentFlowBase {
    if (flowState == null) return '';
    if (flowState!.contains(FLOW_COMPLETED_SUFFIX)) {
      return flowState!.split(FLOW_COMPLETED_SUFFIX).first;
    }
    return flowState!;
  }

  // Get the display name for the next flow
  String get nextFlowDisplayName {
    if (flowState == FLOW_SETUP) return 'Pre-Race';
    if (flowState == FLOW_SETUP_COMPLETED) return 'Pre-Race';
    if (flowState == FLOW_PRE_RACE) return 'Post-Race';
    if (flowState == FLOW_PRE_RACE_COMPLETED) return 'Post-Race';
    if (flowState == FLOW_POST_RACE) return 'Finishing';
    // if (flowState == FLOW_POST_RACE_COMPLETED) return 'Finishing';
    return '';
  }

  // Get the state for the next flow
  String get nextFlowState {
    if (flowState == null) return '';
    int currentIndex = FLOW_SEQUENCE.indexOf(flowState!);
    if (currentIndex >= 0 && currentIndex < FLOW_SEQUENCE.length - 1) {
      return FLOW_SEQUENCE[currentIndex + 1];
    }
    return flowState!; // Return current if at the end
  }

  // Mark the current flow as completed
  String get completedFlowState {
    if (flowState == null) return '';
    if (flowState == FLOW_SETUP) return FLOW_SETUP_COMPLETED;
    if (flowState == FLOW_PRE_RACE) return FLOW_PRE_RACE_COMPLETED;
    // if (flowState == FLOW_POST_RACE) return FLOW_POST_RACE_COMPLETED;
    // Already completed or at finished state
    return flowState!;
  }

  bool get isValid {
    // Basic validation - always required
    if (raceId == null ||
        raceName == null ||
        raceName!.isEmpty ||
        flowState == null ||
        flowState!.isEmpty) {
      return false;
    }

    // For setup phase, only name and flow state are required
    if (flowState == FLOW_SETUP) {
      return true;
    }

    // For completed setup and beyond, require all fields
    return raceDate != null &&
        distance != null &&
        distance! > 0 &&
        distanceUnit != null &&
        distanceUnit!.isNotEmpty;
  }
}
