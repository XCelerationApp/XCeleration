import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';

class JoinedRecord {
  JoinedRecord copyWithExtraTimeLabel() {
    return JoinedRecord(
      runner: runner.copyWithExtraTimeLabel(),
      timeRecord: timeRecord,
    );
  }
  factory JoinedRecord.blank() {
    return JoinedRecord(
      runner: RunnerRecord.blank(),
      timeRecord: TimeRecord.blank(),
    );
  }
  final RunnerRecord runner;
  final TimeRecord timeRecord;

  JoinedRecord({
    required this.runner,
    required this.timeRecord,
  });
}
