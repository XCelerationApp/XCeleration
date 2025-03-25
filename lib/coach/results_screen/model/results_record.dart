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

  String get formattedFinishTime => _formattedFinishTime;
  Duration get finishTime => _finishTime;

  set finishTime(Duration value) {
    _formattedFinishTime = TimeFormatter.formatDuration(value);
    _finishTime = value;
  }

  factory ResultsRecord.fromMap(Map<String, dynamic> map) {
    return ResultsRecord(
      place: map['place'] ?? 0,
      name: map['name'],
      school: map['school'],
      grade: map['grade'],
      bib: map['bib_number'],
      finishTime: map['finish_time'].runtimeType == Duration ? map['finish_time'] : TimeFormatter.loadDurationFromString(map['finish_time']) ?? Duration.zero,
    );
  }
}