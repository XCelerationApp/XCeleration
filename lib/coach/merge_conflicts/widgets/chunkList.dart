import 'package:flutter/material.dart';
import '../controller/merge_conflicts_controller.dart';
import '../model/chunk.dart';
import '../../../utils/enums.dart';
import '../../../core/theme/app_colors.dart';
import 'runner_time_record.dart';
import 'header_widgets.dart';
import 'action_button.dart';

class ChunkList extends StatelessWidget {
  final MergeConflictsController controller;
  const ChunkList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.chunks.length,
      itemBuilder: (context, index) => ChunkItem(
        index: index,
        chunk: controller.chunks[index],
        controller: controller,
      ),
    );
  }
}

class ChunkItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final chunkType = chunk.type;
    final record = chunk.records.last;
    final previousChunk = index > 0 ? controller.chunks[index - 1] : null;
    final previousChunkEndTime =
        previousChunk != null ? previousChunk.records.last.elapsedTime : '0.0';

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
          ...chunk.joinedRecords.map<Widget>((joinedRecord) {
            if (joinedRecord.timeRecord.type == RecordType.runnerTime) {
              return RunnerTimeRecord(
                index: chunk.joinedRecords.indexOf(joinedRecord),
                joinedRecord: joinedRecord,
                color: chunkType == RecordType.runnerTime ||
                        chunkType == RecordType.confirmRunner
                    ? Colors.green
                    : AppColors.primaryColor,
                chunk: chunk,
                controller: controller,
              );
            } else if (joinedRecord.timeRecord.type ==
                RecordType.confirmRunner) {
              return ConfirmationRecord(
                context,
                chunk.joinedRecords.indexOf(joinedRecord),
                joinedRecord.timeRecord,
              );
            }
            return const SizedBox.shrink();
          }),
          if (chunkType == RecordType.extraRunner ||
              chunkType == RecordType.missingRunner)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ActionButton(
                text: 'Resolve Conflict',
                onPressed: () => chunk.handleResolve(
                  controller.handleTooManyTimesResolution,
                  controller.handleTooFewTimesResolution,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
