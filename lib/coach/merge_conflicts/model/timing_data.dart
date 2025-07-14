import '../../../core/utils/enums.dart';
import '../../../shared/models/time_record.dart';
import 'package:xceleration/coach/race_screen/model/race_result.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';

class TimingData {
  List<TimeRecord> records;
  DateTime? startTime;
  String endTime;

  TimingData({
    this.records = const [],
    this.startTime,
    required this.endTime,
  });

  void addRecord(dynamic record) {
    if (record is TimeRecord) {
      records.add(record);
    } else if (record is RunnerRecord) {
      // Convert RunnerRecord to TimeRecord
      records.add(TimeRecord(
        elapsedTime: '',
        isConfirmed: false,
        conflict: null,
        type: RecordType.runnerTime,
        place: records.length + 1,
        runnerId: record.runnerId,
        raceId: record.raceId,
        name: record.name,
        team: record.team,
        teamAbbreviation: record.teamAbbreviation,
        grade: record.grade,
        bib: record.bib,
        error: record.error,
      ));
    }
  }

  // Helper method to merge runner data into a timing record
  void mergeRunnerData(TimeRecord timeRecord, RunnerRecord runnerRecord,
      {int? index}) {
    index ??= records
        .indexWhere((record) => record.runnerId == runnerRecord.runnerId);
    if (index != -1) {
      records[index] = timeRecord.copyWith(
        runnerId: runnerRecord.runnerId,
        raceId: runnerRecord.raceId,
        name: runnerRecord.name,
        team: runnerRecord.team,
        teamAbbreviation: runnerRecord.teamAbbreviation,
        grade: runnerRecord.grade,
        bib: runnerRecord.bib,
        error: runnerRecord.error,
      );
    }
  }

  void updateRecord(int runnerId, TimeRecord updatedRecord) {
    final index = records.indexWhere((record) => record.runnerId == runnerId);
    if (index != -1) {
      records[index] = updatedRecord;
    }
  }

  void removeRecord(int runnerId) {
    records.removeWhere((record) => record.runnerId == runnerId);
  }

  void clearRecords() {
    records.clear();
    startTime = null;
    endTime = '';
  }

  // Get all RunnerRecord info from the TimeRecords
  List<RunnerRecord> get runnerRecords => records
      .where((record) => record.runnerId != null || record.bib != null)
      .map((record) => RunnerRecord(
            runnerId: record.runnerId,
            raceId: record.raceId ?? 0,
            name: record.name ?? '',
            team: record.team ?? '',
            teamAbbreviation: record.teamAbbreviation ?? '',
            grade: int.tryParse(record.grade?.toString() ?? '0') ?? 0,
            bib: record.bib ?? '',
            error: record.error,
          ))
      .toList();

  // Get all RunnerRecord info from the TimeRecords
  List<RaceResult> get raceResults => records
      .where((record) =>
          record.type == RecordType.runnerTime &&
          record.runnerId != null &&
          record.place != null &&
          record.elapsedTime != '')
      .map((record) => RaceResult(
            runnerId: record.runnerId,
            raceId: record.raceId ?? 0,
            place: record.place,
            finishTime: record.elapsedTime,
          ))
      .toList();

  int get numberOfConfirmedTimes =>
      records.where((record) => record.isConfirmed).length;
  int get numberOfTimes => records.length;

  Map<String, dynamic> toJson() => {
        'records': records.map((r) => r.toMap()).toList(),
        'end_time': endTime,
      };

  factory TimingData.fromJson(Map<String, dynamic> json) {
    return TimingData(
      records: (json['records'] as List?)
              ?.map((r) => TimeRecord.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      endTime: json['end_time'] != null ? json['end_time'] as String : '',
    );
  }

  String encode() {
    List<String> recordMaps = records
        .map((record) => (record.type == RecordType.runnerTime)
            ? record.elapsedTime
            : (record.type == RecordType.confirmRunner)
                ? '${record.type.toString()} ${record.place} ${record.elapsedTime}'
                : '${record.type.toString()} ${record.conflict?.data?["offBy"]} ${record.elapsedTime}')
        .toList();
    return recordMaps.join(',');
  }
}
