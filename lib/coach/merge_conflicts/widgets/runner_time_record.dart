import 'package:flutter/material.dart';
import '../controller/merge_conflicts_controller.dart';
import '../model/joined_record.dart';
import '../model/chunk.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/theme/typography.dart';
import 'runner_info_widgets.dart';
import 'time_widgets.dart';

import '../../../utils/enums.dart';

class RunnerTimeRecord extends StatelessWidget {
  final bool isExtraTimeRow;

  const RunnerTimeRecord({
    super.key,
    this.isExtraTimeRow = false,
    required this.controller,
    required this.joinedRecord,
    required this.color,
    required this.chunk,
    required this.index,
    this.isManualEntry = false,
    this.prefilledTime = '',
    this.onManualEntry,
    this.isRemovedTime = false,
    this.assignedTime = '',
    this.onRemoveTime,
    this.availableTimes,
    this.removedTimeIndex,
  });

  final MergeConflictsController controller;
  final JoinedRecord joinedRecord;
  final Color color;
  final Chunk chunk;
  final int index;
  final bool isManualEntry;
  final String prefilledTime;
  final VoidCallback? onManualEntry;
  // Extra runner support
  final bool isRemovedTime;
  final String assignedTime;
  final void Function(int)? onRemoveTime;
  final List<String>? availableTimes;
  final int? removedTimeIndex;

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isExtraTimeRow && timeRecord.place != null && index != -1) ...[
                      PlaceNumber(place: timeRecord.place!, color: conflictColor),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: hasConflict
                    ? (chunk.type == RecordType.missingRunner
                        ? _buildMissingRunnerTimeCell(context)
                        :  _buildExtraRunnerTimeCell(context))
                            // : Portal(
                            //     child: TimeSelector(
                            //       controller: controller,
                            //       timeController: chunk.controllers['timeControllers']![index],
                            //       manualController: chunk.controllers['manualControllers']![index],
                            //       times: chunk.resolve!.availableTimes,
                            //       conflictIndex: chunk.conflictIndex,
                            //       manual: chunk.type != RecordType.extraRunner,
                            //       timeIndex: index,
                            //     ),
                            //   ))
                    : ConfirmedTime(time: timeRecord.elapsedTime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtraRunnerTimeCell(BuildContext context) {
    // If this row's assigned time is the one removed, show placeholder
    return Row(
        children: [
          Expanded(
            child: Text(
              assignedTime.isNotEmpty ? assignedTime : '—',
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ),
          if (removedTimeIndex == null) 
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Remove extra time',
              onPressed: onRemoveTime != null ? () => onRemoveTime!(index) : null,
            ),
        ],
      );
  }

  Widget _buildMissingRunnerTimeCell(BuildContext context) {
    final controller = chunk.controllers['timeControllers']![index];
    if (isManualEntry) {
      return TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Enter missing time',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(),
        ),
        style: AppTypography.smallBodySemibold.copyWith(
          color: AppColors.darkColor,
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: Text(
              prefilledTime.isNotEmpty ? prefilledTime : '—',
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Enter manual time',
            onPressed: onManualEntry,
          ),
        ],
      );
    }
  }
}

// Stateful widget for per-runner missing time cell
class _MissingRunnerTimeCell extends StatefulWidget {
  final TextEditingController controller;
  final String timeText;
  final ValueChanged<String> onManualEntry;
  const _MissingRunnerTimeCell({
    required this.controller,
    required this.timeText,
    required this.onManualEntry,
  });

  @override
  State<_MissingRunnerTimeCell> createState() => _MissingRunnerTimeCellState();
}

class _MissingRunnerTimeCellState extends State<_MissingRunnerTimeCell> {
  bool manualMode = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    manualMode = _controller.text.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (manualMode) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter missing time',
                border: OutlineInputBorder(),
              ),
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
              onSubmitted: (value) {
                setState(() {});
                widget.onManualEntry(value);
              },
              onChanged: (value) {
                setState(() {});
                widget.onManualEntry(value);
              },
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: Text(
              widget.timeText.isNotEmpty ? widget.timeText : '—',
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Enter manual time',
            onPressed: () {
              setState(() {
                manualMode = true;
                _controller.clear();
              });
            },
          ),
        ],
      );
    }
  }
}


