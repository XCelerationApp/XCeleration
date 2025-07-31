import 'package:flutter/material.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'package:xceleration/coach/merge_conflicts/utils/timing_data_converter.dart';

class ChunkList extends StatelessWidget {
  final MergeConflictsController controller;
  const ChunkList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < controller.timingChunks.length; index++)
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
    final previousChunk =
        widget.index > 0 ? widget.controller.timingChunks[widget.index - 1] : null;
    final previousChunkEndTime =
        previousChunk != null ? previousChunk.conflictRecord!.time : '0.0';

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
        ],
      )
    );
  }
}
