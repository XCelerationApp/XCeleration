class RunnerRecord {
  RunnerRecord copyWithExtraTimeLabel() {
    return RunnerRecord(
      bib: bib,
      name: 'Extra Time',
      raceId: raceId,
      grade: grade,
      team: team,
      teamAbbreviation: teamAbbreviation,
      runnerId: runnerId,
      time: time,
      error: error,
      flags: flags,
    );
  }

  factory RunnerRecord.blank() {
    return RunnerRecord(
      bib: '',
      name: '',
      raceId: 0,
      grade: 0,
      team: '',
      teamAbbreviation: '',
      runnerId: null,
      time: null,
      error: null,
      flags: const RunnerRecordFlags(
        notInDatabase: false,
        duplicateBibNumber: false,
        lowConfidenceScore: false,
      ),
    );
  }
  String bib;
  String name;
  String team;
  String teamAbbreviation;
  int grade;
  int raceId;
  int? runnerId;
  String? time;
  String? error;
  RunnerRecordFlags flags;

  RunnerRecord({
    required this.bib,
    required this.name,
    required this.raceId,
    required this.grade,
    required this.team,
    required this.teamAbbreviation,
    this.runnerId,
    this.time,
    this.error,
    this.flags = const RunnerRecordFlags(
      notInDatabase: false,
      duplicateBibNumber: false,
      lowConfidenceScore: false,
    ),
  });

  bool get hasErrors =>
      flags.notInDatabase ||
      flags.duplicateBibNumber ||
      flags.lowConfidenceScore;

  factory RunnerRecord.fromMap(Map<String, dynamic> map) {
    return RunnerRecord(
      bib: map['bib_number'],
      name: map['name'],
      team: map['team'] ?? '',
      teamAbbreviation: map['team_abbreviation'] ?? '',
      grade: map['grade'] ?? 0,
      raceId: map['race_id'] ?? 0, // Default for global runners
      runnerId: map['runner_id'],
      time: map['time'],
      error: map['error'],
      flags: RunnerRecordFlags(
        notInDatabase: map['flags']?['not_in_database'] ?? false,
        duplicateBibNumber: map['flags']?['duplicate_bib_number'] ?? false,
        lowConfidenceScore: map['flags']?['low_confidence_score'] ?? false,
      ),
    );
  }

  /// Factory constructor for joined query results from the new normalized schema
  factory RunnerRecord.fromJoinedMap(Map<String, dynamic> map) {
    return RunnerRecord(
      bib: map['bib_number'],
      name: map['name'],
      team: map['team'] ?? '',
      teamAbbreviation: map['team_abbreviation'] ?? '',
      grade: map['grade'] ?? 0,
      raceId: map['race_id'],
      runnerId: map['runner_id'],
      flags: const RunnerRecordFlags(
        notInDatabase: false,
        duplicateBibNumber: false,
        lowConfidenceScore: false,
      ),
    );
  }

  Map<String, dynamic> toMap({database = false}) {
    if (database) {
      return {
        'bib_number': bib,
        'name': name,
        'race_id': raceId,
        'grade': grade,
        'team': team,
      };
    }
    return {
      'bib_number': bib,
      'name': name,
      'race_id': raceId,
      'grade': grade,
      'team': team,
      'runner_id': runnerId,
      'time': time,
      'error': error,
      'flags': {
        'not_in_database': flags.notInDatabase,
        'duplicate_bib_number': flags.duplicateBibNumber,
        'low_confidence_score': flags.lowConfidenceScore,
      },
    };
  }
}

class RunnerRecordFlags {
  final bool notInDatabase;
  final bool duplicateBibNumber;
  final bool lowConfidenceScore;

  const RunnerRecordFlags({
    required this.notInDatabase,
    required this.duplicateBibNumber,
    required this.lowConfidenceScore,
  });
}
