import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../utils/enums.dart';
import '../model/timing_data.dart';

class RaceInfoHeaderWidget extends StatelessWidget {
  final DateTime? startTime;
  final Duration? endTime;

  const RaceInfoHeaderWidget({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    // Use Consumer for more reliable rebuilds when TimingData changes
    return Consumer<TimingData>(
      builder: (context, timingData, child) {
        final currentRecords = timingData.records;

        final hasRace =
            timingData.raceStopped == false || (endTime != null && currentRecords.isNotEmpty);
        // Calculate runner count by explicitly counting each type
        final runnerTimeCount = currentRecords
            .where((r) => r.type == RecordType.runnerTime && r.place != null)
            .length;
        final runnerCount = runnerTimeCount;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                startTime == null
                    ? 'Ready to start'
                    : timingData.raceStopped
                        ? 'Race finished'
                        : 'Race in progress',
                style: AppTypography.bodyRegular.copyWith(
                  fontSize: 16,
                  color: hasRace
                      ? timingData.raceStopped
                          ? Colors.green[700]
                          : AppColors.primaryColor
                      : Colors.black54,
                  fontWeight: hasRace ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (currentRecords.isNotEmpty)
                Text(
                  'Runners: $runnerCount',
                  style: AppTypography.bodyRegular.copyWith(
                    fontSize: 16,
                    color: hasRace ? Colors.black87 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
