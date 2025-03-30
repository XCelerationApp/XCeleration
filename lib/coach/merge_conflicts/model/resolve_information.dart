import 'package:xcelerate/assistant/race_timer/model/timing_record.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';

class ResolveInformation {
  final List<RunnerRecord> conflictingRunners;
  final List<String>? conflictingTimes;
  final int lastConfirmedPlace;
  final TimingRecord lastConfirmedRecord;
  final int? lastConfirmedIndex;
  final TimingRecord conflictRecord;
  final List<String> availableTimes;
  final List<String> bibData;
  final bool? allowManualEntry;

  ResolveInformation({
    required this.conflictingRunners,
    this.conflictingTimes,
    required this.lastConfirmedPlace,
    required this.lastConfirmedRecord,
    this.lastConfirmedIndex,
    required this.conflictRecord,
    required this.availableTimes,
    required this.bibData,
    this.allowManualEntry,
  });
}
