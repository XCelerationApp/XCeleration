class RunnerRecord {
  String bib;
  String name;
  String school;
  int grade;
  int raceId;
  int? runnerId;
  String? time;
  String? error;

  RunnerRecord({
    required this.bib,
    required this.name,
    required this.raceId,
    required this.grade,
    required this.school,
    this.runnerId,
    this.time,
    this.error,
  });

  factory RunnerRecord.fromMap(Map<String, dynamic> map) {
    return RunnerRecord(
      bib: map['bib_number'],
      name: map['name'],
      raceId: map['race_id'],
      grade: map['grade'],
      school: map['school'],
      runnerId: map['runner_id'],
      time: map['time'],
      error: map['error'],
    );
  }

  Map<String, dynamic> toMap({database = false}) {
    if (database) {
      return {
        'bib_number': bib,
        'name': name,
        'race_id': raceId,
        'grade': grade,
        'school': school,
      };
    }
    return {
      'bib_number': bib,
      'name': name,
      'race_id': raceId,
      'grade': grade,
      'school': school,
      'runner_id': runnerId,
      'time': time,
      'error': error,
    };
  }
}