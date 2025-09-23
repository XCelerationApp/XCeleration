import 'package:flutter/material.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'resolve_conflict_button.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';

class ChunkList extends StatelessWidget {
  final MergeConflictsController controller;
  const ChunkList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < controller.uiChunks.length; index++)
          ChunkItem(
            index: index,
            chunk: controller.uiChunks[index],
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
  final UIChunk chunk;
  final MergeConflictsController controller;

  @override
  State<ChunkItem> createState() => _ChunkItemState();
}

class _ChunkItemState extends State<ChunkItem> {
  @override
  Widget build(BuildContext context) {
    final chunkType = widget.chunk.conflict.type;
    final previousChunk = widget.index > 0
        ? widget.controller.timingChunks[widget.index - 1]
        : null;
    final previousChunkEndTime = previousChunk != null &&
            previousChunk.hasConflict &&
            previousChunk.conflictRecord != null
        ? previousChunk.conflictRecord!.time
        : '0.0';

    return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (chunkType == ConflictType.extraTime ||
                chunkType == ConflictType.missingTime)
              ConflictHeader(
                type: chunkType,
                startTime: previousChunkEndTime,
                endTime: widget.chunk.endTime,
                offBy: widget.chunk.conflict.offBy,
                removedCount: chunkType == ConflictType.extraTime
                    ? widget.chunk.originalTimingDataLength -
                        widget.chunk.times.length
                    : 0,
                enteredCount: chunkType == ConflictType.missingTime
                    ? widget.chunk.originalTimingDataLength -
                        widget.chunk.times.length
                    : 0,
              ),
            if (chunkType == ConflictType.confirmRunner)
              ConfirmHeader(confirmTime: widget.chunk.endTime),
            const SizedBox(height: 8),
            ...widget.chunk.records.asMap().entries.map<Widget>((entry) {
              return RunnerTimeRecord(
                record: entry.value,
                chunk: widget.chunk,
                controller: widget.controller,
                chunkIndex: entry.key,
              );
            }),
            // Add resolve button for all conflict types
            if (chunkType == ConflictType.extraTime ||
                chunkType == ConflictType.missingTime)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ResolveConflictButton(
                  conflictType: chunkType,
                  offBy: widget.chunk.conflict.offBy,
                  onResolve: () {
                    if (chunkType == ConflictType.extraTime) {
                      widget.controller.resolveExtraTimeConflict(widget.index);
                    } else if (chunkType == ConflictType.missingTime) {
                      widget.controller
                          .resolveMissingTimeConflict(widget.index);
                    }
                  },
                ),
              ),
          ],
        ));
  }
}
