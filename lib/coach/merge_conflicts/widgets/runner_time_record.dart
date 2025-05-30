import 'package:flutter/material.dart';
import '../controller/merge_conflicts_controller.dart';
import '../model/joined_record.dart';
import '../model/chunk.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import 'runner_info_widgets.dart';
import 'time_widgets.dart';
import '../../../utils/enums.dart';

class RunnerTimeRecord extends StatelessWidget {
  const RunnerTimeRecord({
    super.key,
    required this.controller,
    required this.joinedRecord,
    required this.color,
    required this.chunk,
    required this.index,
  });
  final MergeConflictsController controller;
  final JoinedRecord joinedRecord;
  final Color color;
  final Chunk chunk;
  final int index;

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
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    PlaceNumber(place: timeRecord.place ?? 0, color: conflictColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RunnerInfo(
                          runner: runner, accentColor: conflictColor),
                    ),
                  ],
                ),
              ),
            ),
            Container(width: 0.5, color: borderColor),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: hasConflict
                    ? TimeSelector(
                        controller: controller,
                        timeController:
                            chunk.controllers['timeControllers']![index],
                        manualController:
                            chunk.controllers['manualControllers']![index],
                        times: chunk.resolve!.availableTimes,
                        conflictIndex: chunk.conflictIndex,
                        manual: chunk.type != RecordType.extraRunner,
                      )
                    : ConfirmedTime(time: timeRecord.elapsedTime),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
