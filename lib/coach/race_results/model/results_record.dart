import '../../../utils/time_formatter.dart' as TimeFormatter;

class ResultsRecord {
  int place;
  final String name;
  final String school;
  final int grade;
  final String bib;
  late Duration _finishTime;
  String _formattedFinishTime = '';

  ResultsRecord({
    required this.place,
    required this.name,
    required this.school,
    required this.grade,
    required this.bib,
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
        bib = other.bib {
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
      'finish_time': TimeFormatter.formatDuration(_finishTime),
    };
  }

  factory ResultsRecord.fromMap(Map<String, dynamic> map) {
    // Check if finish_time is null before using it
    final finishTimeValue = map['finish_time'];
    final Duration processedFinishTime = finishTimeValue == null
        ? Duration.zero
        : finishTimeValue.runtimeType == Duration
            ? finishTimeValue
            : TimeFormatter.loadDurationFromString(finishTimeValue) ??
                Duration.zero;
    
    return ResultsRecord(
      place: map['place'] ?? 0,
      name: map['name'] ?? 'Unknown', 
      school: map['school'] ?? 'Unknown', 
      grade: map['grade'] ?? 0, 
      bib: map['bib_number'] ?? '', 
      finishTime: processedFinishTime,
    );
  }
}
