import 'package:flutter/material.dart';
import '../../../core/utils/enums.dart';
import '../controller/timing_controller.dart';
import '../widgets/record_list_item.dart';
import '../utils/timing_data_converter.dart';
import '../model/ui_record.dart';

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

    // Convert TimingDatum records to UIRecord objects
    final uiRecords =
        TimingDataConverter.convertToUIRecords(controller.records);

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
    switch (uiRecord.type) {
      case RecordType.runnerTime:
        return Dismissible(
          key: ValueKey('${uiRecord.index}_${uiRecord.time}_${uiRecord.place}'),
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
          confirmDismiss: (direction) => _confirmRecordDeletion(uiRecord),
          onDismissed: (direction) => _dismissRecord(uiRecord),
          child: RunnerTimeRecordItem(
            time: uiRecord.time,
            place: uiRecord.place ?? 0,
            textColor: uiRecord.textColor,
            conflict: uiRecord.conflict,
            index: index,
            context: context,
          ),
        );

      case RecordType.confirmRunner:
        return Dismissible(
          key: ValueKey('${uiRecord.index}_${uiRecord.time}_confirm'),
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
          confirmDismiss: (direction) => _confirmRecordDeletion(uiRecord),
          onDismissed: (direction) => _dismissRecord(uiRecord),
          child: ConfirmationRecordItem(
            time: uiRecord.time,
            index: index,
            context: context,
          ),
        );

      case RecordType.missingTime:
      case RecordType.extraTime:
        return Dismissible(
          key: ValueKey('${uiRecord.index}_${uiRecord.time}_${uiRecord.type}'),
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
          confirmDismiss: (direction) => _confirmRecordDeletion(uiRecord),
          onDismissed: (direction) => _dismissRecord(uiRecord),
          child: ConflictRecordItem(
            time: uiRecord.time,
            conflict: uiRecord.conflict!,
            index: index,
            context: context,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<bool> _confirmRecordDeletion(UIRecord uiRecord) async {
    // Handle synthetic records (missing time placeholders)
    if (uiRecord.index == -1) {
      return false; // Synthetic records cannot be deleted directly
    }

    // Find the corresponding TimingDatum record
    if (uiRecord.index < controller.records.length) {
      final timingRecord = controller.records[uiRecord.index];
      return await controller.confirmRecordDeletion(timingRecord);
    }
    return false;
  }

  void _dismissRecord(UIRecord uiRecord) {
    // Handle synthetic records (missing time placeholders)
    if (uiRecord.index == -1) {
      return; // Synthetic records cannot be dismissed directly
    }

    // Find the corresponding TimingDatum record
    if (uiRecord.index < controller.records.length) {
      final timingRecord = controller.records[uiRecord.index];
      controller.dismissTimeRecord(timingRecord);
    }
  }
}
