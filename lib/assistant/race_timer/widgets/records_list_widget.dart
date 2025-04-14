import 'package:flutter/material.dart';
import 'package:xcelerate/utils/enums.dart';
import '../controller/timing_controller.dart';
import '../widgets/record_list_item.dart';


class RecordsListWidget extends StatelessWidget {
  const RecordsListWidget({
    super.key,
    required this.controller,
  });

  final TimingController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.records.isEmpty) {
      return const Center(
        child: Text(
          'No race times yet',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Column(children: [
      Expanded(
          child: ListView.separated(
        controller: controller.scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: controller.records.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final record = controller.records[index];
          if (record.type == RecordType.runnerTime) {
            return Dismissible(
              key: ValueKey(record),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) =>
                  controller.confirmRecordDismiss(record),
              onDismissed: (direction) =>
                  controller.onDismissRunnerTimeRecord(record, index),
              child: RunnerTimeRecordItem(
                record: record,
                index: index,
                context: context,
              ),
            );
          } else if (record.type == RecordType.confirmRunner) {
            return Dismissible(
              key: ValueKey(record),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(
                  Icons.delete,
                  color: Colors.white,
                ),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) =>
                  controller.confirmRecordDismiss(record),
              onDismissed: (direction) =>
                  controller.onDismissConfirmationRecord(record, index),
              child: ConfirmationRecordItem(
                record: record,
                index: index,
                context: context,
              ),
            );
          }
          // } else if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
          //   return Dismissible(
          //     key: ValueKey(record),
          //     background: Container(
          //       color: Colors.red,
          //       alignment: Alignment.centerRight,
          //       padding: const EdgeInsets.only(right: 16.0),
          //       child: const Icon(
          //         Icons.delete,
          //         color: Colors.white,
          //       ),
          //     ),
          //     direction: DismissDirection.endToStart,
          //     confirmDismiss: (direction) => _controller.confirmRecordDismiss(record),
          //     onDismissed: (direction) => _controller.onDismissConflictRecord(record),
          //     child: _buildConflictRecord(record, index),
          //   );
          // }
          return const SizedBox.shrink();
        },
      ))
    ]);
  }
}
