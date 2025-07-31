import 'package:flutter/material.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'runner_info_widgets.dart';
import 'runner_time_cells.dart';

class RunnerTimeRecord extends StatelessWidget {
  final UIRecord record;

  const RunnerTimeRecord({
    super.key,
    required this.record,
    required this.controller,
    required this.chunk,
    required this.chunkIndex,
  });

  final MergeConflictsController controller;
  final UIChunk chunk;
  final int chunkIndex;

  @override
  Widget build(BuildContext context) {
    final raceRunner = record.runner;
    final time = record.time;
    final place = record.place;
    final hasConflict = chunk.conflict.type != ConflictType.confirmRunner;

    final Color conflictColor =
        hasConflict ? AppColors.primaryColor : Colors.green;
    final Color bgColor = ColorUtils.withOpacity(conflictColor, 0.05);
    final Color borderColor = ColorUtils.withOpacity(conflictColor, 0.5);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0.3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (place != null) ...[
                      PlaceNumber(
                          place: place, color: conflictColor),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: RunnerInfo(
                        raceRunner: raceRunner,
                        accentColor: conflictColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 0.5, color: borderColor),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14), // Remove vertical padding
                child: SizedBox.expand(
                  child: hasConflict
                  ? (chunk.conflict.type == ConflictType.missingTime
                    ? MissingTimeCell(
                      controller: record.timeController,
                      time: time,
                      onSubmitted: (newValue) => chunk.onMissingTimeSubmitted(context, chunkIndex, newValue),
                      onChanged: (newValue) => chunk.onMissingTimeChanged(context, chunkIndex, newValue),
                    )
                    : ExtraTimeCell(
                      time: time,
                      onRemoveExtraTime: () => chunk.onRemoveExtraTime(chunkIndex),
                    ))
                  : ConfirmedRunnerTimeCell(time: time),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
