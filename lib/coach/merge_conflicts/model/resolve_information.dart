import '../../../shared/models/time_record.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';

class ResolveInformation {
  final List<RunnerRecord> conflictingRunners;
  final List<String>? conflictingTimes;
  final int lastConfirmedPlace;
  final TimeRecord lastConfirmedRecord;
  final int? lastConfirmedIndex;
  final TimeRecord conflictRecord;
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
