import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../utils/enums.dart';
import '../model/runner_record.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final DateTime? startTime;
  final Duration? endTime;
  final List<RunnerRecord> records;

  const RaceInfoHeaderWidget({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final hasRace = startTime != null || (endTime != null && records.isNotEmpty);
    final isRaceFinished = startTime == null && endTime != null && records.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: hasRace ? const Color(0xFFF5F5F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: hasRace ? Border.all(color: Colors.grey.withOpacity(0.2)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isRaceFinished ? 'Race finished' : (hasRace ? 'Race in progress' : 'Ready to start'),
            style: AppTypography.bodyRegular.copyWith(
              fontSize: 16,
              color: hasRace 
                ? isRaceFinished ? Colors.green[700] : AppColors.primaryColor
                : Colors.black54,
              fontWeight: hasRace ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (records.isNotEmpty)
            Text(
              'Runners: ${records.where((r) => r.type == RecordType.runnerTime).length}',
              style: AppTypography.bodyRegular.copyWith(
                fontSize: 16,
                color: hasRace ? Colors.black87 : Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
