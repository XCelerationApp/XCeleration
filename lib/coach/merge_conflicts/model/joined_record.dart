import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import 'package:xceleration/assistant/race_timer/model/timing_record.dart';

class JoinedRecord {
  final RunnerRecord runner;
  final TimingRecord timeRecord;

  JoinedRecord({
    required this.runner,
    required this.timeRecord,
  });
}
