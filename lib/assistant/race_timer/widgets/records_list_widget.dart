import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/enums.dart';
import '../controller/timing_controller.dart';
import '../model/ui_record.dart';
import '../widgets/record_list_item.dart';

class RecordsListWidget extends StatelessWidget {
  final TimingController controller;
  const RecordsListWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.hasTimingData) {
      return const Center(
        child: Text(
          'No race times yet',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    final uiRecords = controller.uiRecords;

    return Column(children: [
      Expanded(
          child: ListView.separated(
        controller: controller.scrollController,
        physics: const BouncingScrollPhysics(),
        itemCount: uiRecords.length,
        separatorBuilder: (context, index) => const SizedBox(height: 1),
        itemBuilder: (context, index) {
          final uiRecord = uiRecords[index];
          return _buildRecordItem(uiRecord, index, context);
        },
      ))
    ]);
  }

  Widget _buildRecordItem(UIRecord uiRecord, int index, BuildContext context) {
    final item = UIRecordItem(uiRecord: uiRecord, index: index);

    final bool canSwipe = (uiRecord.textColor == Colors.black) || // unconfirmed
        (uiRecord.type != RecordType.runnerTime &&
            index == controller.uiRecords.length - 1); // conflict and last

    if (!canSwipe) return item;

    return Dismissible(
      key: ValueKey('${index}_${uiRecord.time}_${uiRecord.type}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmRecordDeletion(uiRecord),
      child: item,
    );
  }

  Future<bool> _confirmRecordDeletion(UIRecord uiRecord) async {
    return await controller.handleRecordDeletion(uiRecord);
  }
}
