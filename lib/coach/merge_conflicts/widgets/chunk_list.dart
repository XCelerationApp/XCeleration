import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../controller/merge_conflicts_controller.dart';
import '../model/chunk.dart';
import '../../../utils/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../model/joined_record.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'action_button.dart';


class ChunkList extends StatelessWidget {
  final MergeConflictsController controller;
  const ChunkList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < controller.chunks.length; index++)
          ChunkItem(
            index: index,
            chunk: controller.chunks[index],
            controller: controller,
          ),
      ],
    );
  }
}

class ChunkItem extends StatefulWidget {
  const ChunkItem({
    super.key,
    required this.index,
    required this.chunk,
    required this.controller,
  });
  final int index;
  final Chunk chunk;
  final MergeConflictsController controller;

  @override
  State<ChunkItem> createState() => _ChunkItemState();
}

class _ChunkItemState extends State<ChunkItem> {
  int? manualEntryIndex;
  int? removedTimeIndex;

  @override
  Widget build(BuildContext context) {
    final chunkType = widget.chunk.type;
    final record = widget.chunk.records.last;
    final previousChunk = widget.index > 0 ? widget.controller.chunks[widget.index - 1] : null;
    final previousChunkEndTime =
        previousChunk != null ? previousChunk.records.last.elapsedTime : '0.0';

    List<String> availableTimes = widget.chunk.resolve?.availableTimes ?? [];
    int runnerCount = widget.chunk.joinedRecords.length;
    // Compute shifted times for missingRunner: skip manualEntryIndex
    List<String> shiftedTimes = [];
    // Compute assigned times for extraRunner: skip removedTimeIndex
    List<String> assignedTimes = [];
    if (chunkType == RecordType.missingRunner) {
      int timeIdx = 0;
      for (int i = 0; i < runnerCount; i++) {
        if (i == manualEntryIndex) {
          shiftedTimes.add('');
        } else if (timeIdx < availableTimes.length) {
          shiftedTimes.add(availableTimes[timeIdx]);
          timeIdx++;
        } else {
          shiftedTimes.add('');
        }
      }
    } else if (chunkType == RecordType.extraRunner) {
      for (int i = 0; i < availableTimes.length; i++) {
        if (i == removedTimeIndex) continue;
        assignedTimes.add(availableTimes[i]);
      }
    }

    // DEBUG: Print availableTimes and runnerCount
    Logger.d('availableTimes: $availableTimes, runnerCount: $runnerCount');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chunkType == RecordType.extraRunner ||
              chunkType == RecordType.missingRunner)
            ConflictHeader(
              type: chunkType,
              conflictRecord: record,
              startTime: previousChunkEndTime,
              endTime: record.elapsedTime,
            ),
          if (chunkType == RecordType.confirmRunner)
            ConfirmHeader(confirmRecord: record),
          const SizedBox(height: 8),
          ...widget.chunk.joinedRecords.asMap().entries.map<Widget>((entry) {
            final i = entry.key;
            final joinedRecord = entry.value;
            if (joinedRecord.timeRecord.type == RecordType.runnerTime) {
              if (chunkType == RecordType.missingRunner) {
                final isManual = manualEntryIndex == i;
                final controller = widget.chunk.controllers['timeControllers']![i];
                if (!isManual) {
                  // Always assign prefilled time to the controller for validation
                  controller.text = shiftedTimes[i];
                }
                return RunnerTimeRecord(
                  index: i,
                  joinedRecord: joinedRecord,
                  color: chunkType == RecordType.runnerTime ||
                          chunkType == RecordType.confirmRunner
                      ? Colors.green
                      : AppColors.primaryColor,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  isManualEntry: isManual,
                  prefilledTime: shiftedTimes[i],
                  onManualEntry: () {
                    setState(() {
                      manualEntryIndex = i;
                      // Clear the text so the textfield is blank
                      controller.clear();
                    });
                  },
                );
              } else if (chunkType == RecordType.extraRunner) {
                // Assign times skipping removedTimeIndex
                final assignedTime = (i < assignedTimes.length) ? assignedTimes[i] : '';
                final controller = widget.chunk.controllers['timeControllers']![i];
                controller.text = assignedTime;
                final isRemovedTime = i == removedTimeIndex;
                // Only show X on runner rows if no time is currently removed
                final showRemove = removedTimeIndex == null;
                return RunnerTimeRecord(
                  index: i,
                  joinedRecord: joinedRecord,
                  color: AppColors.primaryColor,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  isRemovedTime: isRemovedTime,
                  assignedTime: assignedTime,
                  onRemoveTime: showRemove
                      ? (int timeIdx) {
                          setState(() {
                            removedTimeIndex = timeIdx;
                          });
                        }
                      : null,
                  availableTimes: availableTimes,
                  removedTimeIndex: removedTimeIndex,
                );
              } else if (chunkType == RecordType.confirmRunner) {
                // Render confirmed runner row
                return RunnerTimeRecord(
                  index: i,
                  joinedRecord: joinedRecord,
                  color: Colors.green,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  assignedTime: joinedRecord.timeRecord.elapsedTime,
                );
              }
            }
            return const SizedBox.shrink();
          }),
          if (chunkType == RecordType.extraRunner && availableTimes.length > runnerCount && removedTimeIndex == null)
            (() {
              int extraTimeIdx = availableTimes.length - 1;
              // Extract just the time portion if the string includes a name (e.g., 'oliver11.08' -> '11.08')
              final extraTime = availableTimes[extraTimeIdx];
              final blankJoinedRecord = JoinedRecord.blank().copyWithExtraTimeLabel();
              return RunnerTimeRecord(
                index: -1, // Dummy index for extra time row (no place)
                joinedRecord: blankJoinedRecord,
                color: AppColors.primaryColor,
                chunk: widget.chunk,
                controller: widget.controller,
                isRemovedTime: false,
                assignedTime: extraTime,
                onRemoveTime: (_) {
                  setState(() {
                    removedTimeIndex = extraTimeIdx;
                  });
                },
                availableTimes: availableTimes,
                removedTimeIndex: removedTimeIndex,
                isExtraTimeRow: true,
              );
            })(),
          // If the extra time is removed, show an Undo button below the times
          if (chunkType == RecordType.extraRunner && availableTimes.length > runnerCount && removedTimeIndex != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo Remove Extra Time'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      removedTimeIndex = null;
                    });
                  },
                ),
              ),
            ),
          if (chunkType == RecordType.extraRunner ||
              chunkType == RecordType.missingRunner)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ActionButton(
                text: 'Resolve Conflict',
                onPressed: () => widget.chunk.handleResolve(
                  widget.controller.handleTooManyTimesResolution,
                  widget.controller.handleTooFewTimesResolution,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
