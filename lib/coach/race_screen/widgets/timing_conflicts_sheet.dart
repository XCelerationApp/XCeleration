import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../merge_conflicts_screen/screen/merge_conflicts_screen.dart';
import '../../merge_conflicts_screen/model/timing_data.dart';
// import '../../../assistant/race_timer/timing_screen/model/timing_record.dart';
import '../widgets/runner_record.dart';

class TimingConflictsSheet extends StatelessWidget {
  final List<RunnerRecord> conflictingRecords;
  final TimingData timingData;
  final List<RunnerRecord> runnerRecords;
  final int raceId;

  const TimingConflictsSheet({
    Key? key, 
    required this.conflictingRecords,
    required this.timingData,
    required this.runnerRecords,
    required this.raceId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            AppBar(
              title: Text(
                'Resolve Timing Conflicts',
                style: AppTypography.titleSemibold,
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Timing Conflicts',
                      style: AppTypography.titleSemibold,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The following runners have timing conflicts that need to be resolved:',
                      style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: conflictingRecords.length,
                        itemBuilder: (context, index) {
                          final RunnerRecord record = conflictingRecords[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Bib #${record.bib}',
                                        style: AppTypography.bodySemibold,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Conflict',
                                          style: AppTypography.bodySmall.copyWith(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Multiple times recorded',
                                    style: AppTypography.bodyRegular,
                                  ),
                                  // const SizedBox(height: 8),
                                  // Text(
                                  //   'Times: ${record.times.join(', ')}',
                                  //   style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor.withOpacity(0.7)),
                                  // ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () {
                          // Navigate to detailed conflict resolution page
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MergeConflictsScreen(
                                raceId: raceId,
                                timingData: timingData,
                                runnerRecords: runnerRecords,
                                onComplete: (resolvedData) {
                                  Navigator.pop(context, resolvedData);
                                },
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'Resolve Conflicts',
                          style: AppTypography.bodySemibold.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
