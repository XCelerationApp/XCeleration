import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/enums.dart';
import '../controller/merge_conflicts_controller.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'resolve_conflict_button.dart';
import 'undo_button.dart';
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
          // Nested in the screen's scroll view: no safe-area inset of its own.
          padding: EdgeInsets.zero,
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
    final previousChunkEndTime =
        widget.controller.previousEndTimeFor(widget.chunk.chunkId);
    final undoLabel = widget.controller.undoLabel(widget.chunk.chunkId);

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
                child: Row(
                  children: [
                    // Slides in the first time there is something to take
                    // back, rather than jumping the resolve button sideways.
                    AnimatedSize(
                      duration: AppAnimations.fast,
                      curve: AppAnimations.spring,
                      child: undoLabel == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              child: UndoButton(
                                label: undoLabel,
                                onUndo: () => widget.controller
                                    .undo(widget.chunk.chunkId),
                              ),
                            ),
                    ),
                    Expanded(
                      child: ResolveConflictButton(
                        isResolved: widget.chunk.isResolvedLocally,
                        onResolve: () async {
                          if (chunkType == ConflictType.extraTime) {
                            await widget.controller
                                .resolveExtraTimeConflict(widget.chunk.chunkId);
                          } else if (chunkType == ConflictType.missingTime) {
                            await widget.controller.resolveMissingTimeConflict(
                                widget.chunk.chunkId);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ));
  }
}
