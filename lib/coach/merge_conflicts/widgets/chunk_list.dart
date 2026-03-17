import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'resolve_conflict_button.dart';
import 'package:xceleration/coach/merge_conflicts/models/ui_chunk.dart';

class ChunkList extends StatelessWidget {
  const ChunkList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MergeConflictsController>(
      builder: (context, controller, _) {
        final chunks = controller.uiChunks;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chunks.length,
          itemBuilder: (context, index) => ChunkItem(
            key: ValueKey(chunks[index].chunkId),
            index: index,
            chunk: chunks[index],
            controller: controller,
          ),
        );
      },
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
                removedCount: widget.chunk.removedCount,
                enteredCount: widget.chunk.enteredCount,
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
            // Add resolve button for unresolved conflict types
            if (chunkType == ConflictType.extraTime ||
                chunkType == ConflictType.missingTime)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ResolveConflictButton(
                  isResolved: widget.chunk.isResolvedLocally,
                  onResolve: () async {
                    if (chunkType == ConflictType.extraTime) {
                      await widget.controller
                          .resolveExtraTimeConflict(widget.index);
                    } else if (chunkType == ConflictType.missingTime) {
                      await widget.controller
                          .resolveMissingTimeConflict(widget.index);
                    }
                  },
                ),
              ),
          ],
        ));
  }
}
