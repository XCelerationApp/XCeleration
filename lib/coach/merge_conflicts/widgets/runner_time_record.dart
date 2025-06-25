import 'package:flutter/material.dart';
import '../../../utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import '../model/joined_record.dart';
import '../model/chunk.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'runner_info_widgets.dart';
import 'runner_time_cells.dart';

class RunnerTimeRecord extends StatelessWidget {
  final bool isExtraTimeRow;
  final ValueChanged<String>? onTimeSubmitted;
  final int? removableTimeIndex;
  final int? removedTimeIndex = null;

  const RunnerTimeRecord({
    super.key,
    this.isExtraTimeRow = false,
    required this.controller,
    required this.joinedRecord,
    required this.color,
    required this.chunk,
    required this.index,
    required this.textEditingController,
    this.isManualEntry = false,
    this.assignedTime = '',
    this.onManualEntry,
    this.isRemovedTime = false,
    this.onRemoveTime,
    this.availableTimes,
    this.removedTimeIndices,
    this.onTimeSubmitted,
    this.removableTimeIndex,
  });

  final MergeConflictsController controller;
  final JoinedRecord joinedRecord;
  final Color color;
  final Chunk chunk;
  final int index;
  final TextEditingController textEditingController;
  final bool isManualEntry;
  final String assignedTime;
  final VoidCallback? onManualEntry;
  // Extra time support
  final bool isRemovedTime;
  final void Function(int)? onRemoveTime;
  final List<String>? availableTimes;
  final Set<int>? removedTimeIndices;

  @override
  Widget build(BuildContext context) {
    final runner = joinedRecord.runner;
    final timeRecord = joinedRecord.timeRecord;
    final hasConflict = chunk.resolve != null;

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
                    if (!isExtraTimeRow &&
                        timeRecord.place != null &&
                        index != -1) ...[
                      PlaceNumber(
                          place: timeRecord.place!, color: conflictColor),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: RunnerInfo(
                        runner: runner,
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
                      ? (chunk.type == RecordType.missingTime
                          ? MissingTimeCell(
                              controller: textEditingController,
                              isManualEntry: isManualEntry,
                              assignedTime: assignedTime,
                              onManualEntry: onManualEntry,
                              onSubmitted: onTimeSubmitted,
                            )
                          : ExtraTimeCell(
                              assignedTime: assignedTime,
                              removedTimeIndices: removedTimeIndices,
                              removableTimeIndex: removableTimeIndex,
                              onRemoveTime: onRemoveTime,
                              isRemovedTime: isRemovedTime,
                            ))
                      : ConfirmedRunnerTimeCell(time: timeRecord.elapsedTime),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
