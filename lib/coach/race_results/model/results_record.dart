import '../../../core/utils/time_formatter.dart';

class ResultsRecord {
  int place;
  final String name;
  final String team;
  final String teamAbbreviation;
  final int grade;
  final String bib;
  final int raceId;
  final int runnerId;
  late Duration _finishTime;
  String _formattedFinishTime = '';
  // Optional pace per mile
  Duration? _pacePerMile;
  String _formattedPacePerMile = '';

  ResultsRecord({
    required this.place,
    required this.name,
    required this.team,
    required this.teamAbbreviation,
    required this.grade,
    required this.bib,
    required this.raceId,
    required this.runnerId,
    required finishTime,
    Duration? pacePerMile,
  }) {
    _finishTime = finishTime;
    _formattedFinishTime = TimeFormatter.formatDuration(finishTime);
    _pacePerMile = pacePerMile;
    _formattedPacePerMile =
        pacePerMile == null ? '' : TimeFormatter.formatDuration(pacePerMile);
  }

  // Copy constructor to create independent copies
  ResultsRecord.copy(ResultsRecord other)
      : place = other.place,
        name = other.name,
        team = other.team,
        teamAbbreviation = other.teamAbbreviation,
        grade = other.grade,
        bib = other.bib,
        raceId = other.raceId,
        runnerId = other.runnerId {
    _finishTime = other._finishTime;
    _formattedFinishTime = other._formattedFinishTime;
    _pacePerMile = other._pacePerMile;
    _formattedPacePerMile = other._formattedPacePerMile;
  }

  String get formattedFinishTime => _formattedFinishTime;
  Duration get finishTime => _finishTime;
  Duration? get pacePerMile => _pacePerMile;
  String get formattedPacePerMile => _formattedPacePerMile;

  set finishTime(Duration value) {
    _formattedFinishTime = TimeFormatter.formatDuration(value);
    _finishTime = value;
  }

  set pacePerMile(Duration? value) {
    _pacePerMile = value;
    _formattedPacePerMile =
        value == null ? '' : TimeFormatter.formatDuration(value);
  }

  Map<String, dynamic> toMap() {
    return {
      'place': place,
      'name': name,
      'team': team,
      'team_abbreviation': teamAbbreviation,
      'grade': grade,
      'bib_number': bib,
      'race_id': raceId,
      'runner_id': runnerId,
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
      team: map['team'] ?? 'Unknown',
      teamAbbreviation: map['team_abbreviation'] ?? 'N/A',
      grade: map['grade'] ?? 0,
      bib: map['bib_number'] ?? '',
      raceId: map['race_id'] ?? 0,
      runnerId: map['runner_id'] ?? 0,
      finishTime: processedFinishTime,
    );
  }
}
