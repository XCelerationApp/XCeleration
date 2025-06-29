import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import '../model/chunk.dart';
import '../../../core/theme/app_colors.dart';
import '../model/joined_record.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import '../../../core/components/button_components.dart';
import 'package:xceleration/core/utils/time_formatter.dart';

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
  Set<int> manualEntryIndices = {}; // Track multiple manual entries
  final Map<int, String?> _manualEntries =
      {}; // Map originalIndex to manual time
  Set<int> removedTimeIndices = {}; // Track multiple removed extra times
  late List<JoinedRecord> _sortedJoinedRecords; // New: To manage display order

  @override
  void initState() {
    super.initState();
    _sortedJoinedRecords =
        List.from(widget.chunk.joinedRecords); // Initialize with chunk's data
    _sortRecords(); // Initial sort
  }

  @override
  void didUpdateWidget(covariant ChunkItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chunk.joinedRecords != oldWidget.chunk.joinedRecords) {
      _sortedJoinedRecords = List.from(widget.chunk.joinedRecords);
      _sortRecords(); // Re-sort if the underlying data changes
    }
  }

  // New: Method to sort joined records
  void _sortRecords() {
    setState(() {
      _sortedJoinedRecords.sort((a, b) {
        // Handle null or empty times by pushing them to the end
        final timeA = a.timeRecord.elapsedTime;
        final timeB = b.timeRecord.elapsedTime;

        final isValidA = timeA.isNotEmpty &&
            timeA != 'TBD' &&
            TimeFormatter.loadDurationFromString(timeA) != null;
        final isValidB = timeB.isNotEmpty &&
            timeB != 'TBD' &&
            TimeFormatter.loadDurationFromString(timeB) != null;

        if (!isValidA && !isValidB) {
          return 0; // Both invalid, maintain original order
        }
        if (!isValidA) return 1; // A is invalid, push to end
        if (!isValidB) return -1; // B is invalid, push to end

        // Both are valid, compare durations
        final durationA = TimeFormatter.loadDurationFromString(timeA)!;
        final durationB = TimeFormatter.loadDurationFromString(timeB)!;
        return durationA.compareTo(durationB);
      });
    });
  }

  // New: Callback for when a time is submitted
  void _onTimeSubmitted(int originalIndex, String newValue) {
    // Validate the input
    if (newValue.isNotEmpty &&
        newValue != 'TBD' &&
        TimeFormatter.loadDurationFromString(newValue) == null) {
      // Invalid time format, show error and don't update
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid time format. Please use MM:SS.ms or SS.ms')),
      );
      // Revert the text field content to previous valid state or clear it
      final controller =
          widget.chunk.controllers['timeControllers']![originalIndex];
      // If it's a manual entry, revert to its stored value or empty.
      // Else, revert to the joinedRecord's time.
      if (_manualEntries.containsKey(originalIndex)) {
        controller.text = _manualEntries[originalIndex] ?? '';
      } else {
        controller.text =
            widget.chunk.joinedRecords[originalIndex].timeRecord.elapsedTime;
      }
      return;
    }

    setState(() {
      if (_manualEntries.containsKey(originalIndex)) {
        _manualEntries[originalIndex] = newValue; // Update stored manual entry
        // No direct update to TimingData here, it will be part of resolution.
      } else {
        final joinedRecord = widget.chunk.joinedRecords[originalIndex];
        joinedRecord.timeRecord.elapsedTime = newValue;

        _sortRecords();

        // Notify the controller about the change to update the underlying TimingData
        widget.controller.updateRecordInTimingData(
          joinedRecord.timeRecord,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chunkType = widget.chunk.type;
    final record = widget.chunk.records.last;
    final previousChunk =
        widget.index > 0 ? widget.controller.chunks[widget.index - 1] : null;
    final previousChunkEndTime =
        previousChunk != null ? previousChunk.records.last.elapsedTime : '0.0';

    List<String> availableTimes = widget.chunk.resolve?.availableTimes ?? [];
    int runnerCount = widget.chunk.joinedRecords.length;
    // Get offBy value from conflict record
    int offBy = 1;
    if (record.conflict?.data != null &&
        record.conflict!.data!['offBy'] != null) {
      offBy = record.conflict!.data!['offBy'] as int;
    }

    List<String> shiftedTimes = List.filled(runnerCount,
        ''); // This length is correct for the number of runners (rows)
    List<String> assignedTimes = []; // Initialize for broader scope

    if (chunkType == RecordType.missingTime) {
      int sourceTimeIndex = 0; // Index into availableTimes

      // Iterate through the runners' original indices (0 to runnerCount-1)
      for (int i = 0; i < runnerCount; i++) {
        if (_manualEntries.containsKey(i)) {
          // This runner's slot is for a manual entry
          shiftedTimes[i] = _manualEntries[i] ?? '';
          // The original time that *would have been* at `availableTimes[sourceTimeIndex]`
          // is effectively "shifted down" to the next available non-manual slot.
          // So, we don't advance `sourceTimeIndex` here.
        } else {
          // This runner's slot is for an available time.
          if (sourceTimeIndex < availableTimes.length) {
            shiftedTimes[i] = availableTimes[sourceTimeIndex];
            sourceTimeIndex++; // Advance to the next available time for the next non-manual slot
          } else {
            shiftedTimes[i] = ''; // No more available times to shift
          }
        }
      }
    } else if (chunkType == RecordType.extraTime) {
      // For extra time conflicts, filter out removed times and assign remaining times to runners
      List<String> nonRemovedTimes = [];
      for (int i = 0; i < availableTimes.length; i++) {
        if (!removedTimeIndices.contains(i)) {
          nonRemovedTimes.add(availableTimes[i]);
        }
      }

      // Assign the non-removed times to runners in order
      assignedTimes = List.filled(runnerCount, '');
      for (int i = 0; i < runnerCount && i < nonRemovedTimes.length; i++) {
        assignedTimes[i] = nonRemovedTimes[i];
      }
    }

    // DEBUG: Print availableTimes and runnerCount
    Logger.d(
        'availableTimes: $availableTimes, runnerCount: $runnerCount, offBy: $offBy, manualEntryIndices.length: ${manualEntryIndices.length}, onManualEntry_enabled: ${manualEntryIndices.length < offBy}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chunkType == RecordType.extraTime ||
              chunkType == RecordType.missingTime)
            ConflictHeader(
              type: chunkType,
              conflictRecord: record,
              startTime: previousChunkEndTime,
              endTime: record.elapsedTime,
              offBy: offBy,
              removedCount: chunkType == RecordType.extraTime
                  ? removedTimeIndices.length
                  : 0,
              enteredCount: chunkType == RecordType.missingTime
                  ? _manualEntries.length
                  : 0,
            ),
          if (chunkType == RecordType.confirmRunner)
            ConfirmHeader(confirmRecord: record),
          if (chunkType == RecordType.runnerTime)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Clean Results - No Conflicts',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Use _sortedJoinedRecords for rendering
          ..._sortedJoinedRecords.asMap().entries.map<Widget>((entry) {
            final joinedRecord = entry.value; // This is the sorted joinedRecord

            // Pass the original index of the joinedRecord for controller lookup
            final originalIndex =
                widget.chunk.joinedRecords.indexOf(joinedRecord);

            if (joinedRecord.timeRecord.type == RecordType.runnerTime) {
              if (chunkType == RecordType.missingTime) {
                final isManual = _manualEntries.containsKey(originalIndex);
                final controller =
                    widget.chunk.controllers['timeControllers']![originalIndex];
                if (isManual) {
                  // If it's a manual entry, use the stored manual value (or empty if null)
                  controller.text = _manualEntries[originalIndex] ?? '';
                } else {
                  // Otherwise, use the shifted time
                  controller.text = shiftedTimes[originalIndex];
                }
                return RunnerTimeRecord(
                  index: originalIndex, // Pass original index for actions
                  joinedRecord: joinedRecord,
                  color: chunkType == RecordType.runnerTime ||
                          chunkType == RecordType.confirmRunner
                      ? Colors.green
                      : AppColors.primaryColor,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  isManualEntry: isManual,
                  assignedTime: shiftedTimes[originalIndex],
                  onManualEntry: () {
                    setState(() {
                      _manualEntries[originalIndex] =
                          null; // Mark for manual entry, pending input
                      controller.clear();
                    });
                  },
                  textEditingController:
                      controller, // Pass the specific controller
                  onTimeSubmitted: (newValue) {
                    _onTimeSubmitted(originalIndex, newValue);
                  },
                );
              } else if (chunkType == RecordType.extraTime) {
                final assignedTime = originalIndex < assignedTimes.length
                    ? assignedTimes[originalIndex]
                    : '';
                final controller =
                    widget.chunk.controllers['timeControllers']![originalIndex];
                controller.text = assignedTime;
                final canRemoveMore = removedTimeIndices.length < offBy;
                return RunnerTimeRecord(
                  index: originalIndex,
                  joinedRecord: joinedRecord,
                  color: AppColors.primaryColor,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  assignedTime: assignedTime,
                  availableTimes: availableTimes,
                  removedTimeIndices: removedTimeIndices,
                  textEditingController: controller,
                  isRemovedTime: assignedTime.isNotEmpty &&
                      removedTimeIndices
                          .contains(availableTimes.indexOf(assignedTime)),
                  onRemoveTime: canRemoveMore && assignedTime.isNotEmpty
                      ? (timeIdx) {
                          setState(() {
                            // Find the index of the assigned time in availableTimes
                            final timeIndexToRemove =
                                availableTimes.indexOf(assignedTime);
                            if (timeIndexToRemove != -1) {
                              Logger.d(
                                  'Before removal: removedTimeIndices=$removedTimeIndices, removing time "$assignedTime" at index $timeIndexToRemove');
                              removedTimeIndices.add(timeIndexToRemove);
                              Logger.d(
                                  'After removal: removedTimeIndices=$removedTimeIndices');
                              // Update the chunk with the removed indices
                              widget.chunk
                                  .updateRemovedTimeIndices(removedTimeIndices);
                            }
                          });
                        }
                      : null,
                  removableTimeIndex: assignedTime.isNotEmpty
                      ? availableTimes.indexOf(assignedTime)
                      : -1,
                );
              } else if (chunkType == RecordType.confirmRunner) {
                return RunnerTimeRecord(
                  index: originalIndex,
                  joinedRecord: joinedRecord,
                  color: Colors.green,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  assignedTime: joinedRecord.timeRecord.elapsedTime,
                  textEditingController: widget
                      .chunk.controllers['timeControllers']![originalIndex],
                );
              } else if (chunkType == RecordType.runnerTime) {
                // Handle clean race scenarios - display runner times normally
                final controller =
                    widget.chunk.controllers['timeControllers']![originalIndex];
                controller.text = joinedRecord.timeRecord.elapsedTime;
                return RunnerTimeRecord(
                  index: originalIndex,
                  joinedRecord: joinedRecord,
                  color: Colors.green,
                  chunk: widget.chunk,
                  controller: widget.controller,
                  assignedTime: joinedRecord.timeRecord.elapsedTime,
                  textEditingController: controller,
                );
              }
            }
            return const SizedBox.shrink();
          }),
          // Show extra times that haven't been removed - but only show as many as needed
          if (chunkType == RecordType.extraTime &&
              availableTimes.length > runnerCount)
            ...() {
              List<Widget> extraTimeWidgets = [];
              int extraTimesShown = 0;
              final maxExtraTimesToShow = offBy - removedTimeIndices.length;

              for (int timeIdx = runnerCount;
                  timeIdx < availableTimes.length &&
                      extraTimesShown < maxExtraTimesToShow;
                  timeIdx++) {
                // Only show this extra time if it hasn't been removed
                if (!removedTimeIndices.contains(timeIdx)) {
                  final extraTime = availableTimes[timeIdx];
                  final blankJoinedRecord =
                      JoinedRecord.blank().copyWithExtraTimeLabel();
                  final extraTimeController =
                      TextEditingController(text: extraTime);
                  final canRemoveMore = removedTimeIndices.length < offBy;

                  extraTimeWidgets.add(RunnerTimeRecord(
                    index: -1, // Dummy index for extra time row (no place)
                    joinedRecord: blankJoinedRecord,
                    color: AppColors.primaryColor,
                    chunk: widget.chunk,
                    controller: widget.controller,
                    isRemovedTime:
                        false, // This time is not removed (we filtered those out)
                    assignedTime: extraTime,
                    onRemoveTime: canRemoveMore
                        ? (removedTimeIdx) {
                            setState(() {
                              Logger.d(
                                  'Before removal: removedTimeIndices=$removedTimeIndices, adding timeIdx=$timeIdx');
                              removedTimeIndices.add(timeIdx);
                              Logger.d(
                                  'After removal: removedTimeIndices=$removedTimeIndices');
                              // Update the chunk with the removed indices
                              widget.chunk
                                  .updateRemovedTimeIndices(removedTimeIndices);
                            });
                          }
                        : null,
                    availableTimes: availableTimes,
                    removedTimeIndices: removedTimeIndices,
                    isExtraTimeRow: true,
                    textEditingController: extraTimeController,
                    removableTimeIndex: timeIdx,
                  ));
                  extraTimesShown++;
                }
              }
              return extraTimeWidgets;
            }(),
          // If any extra time is removed, show an Undo button below the times
          if (chunkType == RecordType.extraTime &&
              removedTimeIndices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.undo),
                  label: Text(
                      'Undo Remove Extra Time (${removedTimeIndices.length}/$offBy removed)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      if (removedTimeIndices.isNotEmpty) {
                        removedTimeIndices.remove(removedTimeIndices.last);
                        // Update the chunk with the removed indices
                        widget.chunk
                            .updateRemovedTimeIndices(removedTimeIndices);
                      }
                    });
                  },
                ),
              ),
            ),
          if (chunkType == RecordType.extraTime ||
              chunkType == RecordType.missingTime)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SharedActionButton(
                text: 'Resolve Conflict',
                onPressed: () => widget.chunk.handleResolve(
                  widget.controller.handleExtraTimesResolution,
                  widget.controller.handleMissingTimesResolution,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
