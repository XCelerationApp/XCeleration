import '../../../utils/time_formatter.dart' as TimeFormatter;

class ResultsRecord {
  int place;
  final String name;
  final String school;
  final int grade;
  final String bib;
  final int raceId;
  final int runnerId;
  late Duration _finishTime;
  String _formattedFinishTime = '';

  ResultsRecord({
    required this.place,
    required this.name,
    required this.school,
    required this.grade,
    required this.bib,
    required this.raceId,
    required this.runnerId,
    required finishTime,
  }) {
    _finishTime = finishTime;
    _formattedFinishTime = TimeFormatter.formatDuration(finishTime);
  }

  // Copy constructor to create independent copies
  ResultsRecord.copy(ResultsRecord other)
      : place = other.place,
        name = other.name,
        school = other.school,
        grade = other.grade,
        bib = other.bib,
        raceId = other.raceId,
        runnerId = other.runnerId {
    _finishTime = other._finishTime;
    _formattedFinishTime = other._formattedFinishTime;
  }

  String get formattedFinishTime => _formattedFinishTime;
  Duration get finishTime => _finishTime;

  set finishTime(Duration value) {
    _formattedFinishTime = TimeFormatter.formatDuration(value);
    _finishTime = value;
  }

  Map<String, dynamic> toMap() {
    return {
      'place': place,
      'name': name,
      'school': school,
      'grade': grade,
      'bib_number': bib,
      'race_id': raceId,
      'runner_id': runnerId,
      'finish_time': TimeFormatter.formatDuration(_finishTime),
    };
  }

  factory ResultsRecord.fromMap(Map<String, dynamic> map) {
    return ResultsRecord(
      place: map['place'] ?? 0,
      name: map['name'],
      school: map['school'],
      grade: map['grade'],
      bib: map['bib_number'],
      raceId: map['race_id'],
      runnerId: map['runner_id'],
      finishTime: map['finish_time'].runtimeType == Duration
          ? map['finish_time']
          : TimeFormatter.loadDurationFromString(map['finish_time']) ??
              Duration.zero,
    );
  }
}
