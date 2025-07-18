import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';
import '../model/ui_record.dart';


class UIRecordItem extends StatelessWidget {
  final UIRecord uiRecord;
  final int index;

  const UIRecordItem({
    super.key,
    required this.uiRecord,
    required this.index,
  });

  Widget _timeRecordBody(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${uiRecord.place}',
          style: AppTypography.headerSemibold.copyWith(
            color: uiRecord.textColor,
          ),
        ),
        Text(
          uiRecord.time,
          style: AppTypography.headerSemibold.copyWith(
            color: uiRecord.textColor,
          ),
        ),
      ],
    );
  }

  Widget _confirmRecordBody(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Confirmed: ${uiRecord.time}',
          style: AppTypography.headerSemibold.copyWith(
            color: Colors.green[700],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.01,
        0,
      ),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF5F5F5) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: uiRecord.type != RecordType.confirmRunner ? _timeRecordBody(context) : _confirmRecordBody(context),
    );
  }
}

class ConfirmationRecordItem extends StatelessWidget {
  final int index;
  final String time;
  final BuildContext context;

  const ConfirmationRecordItem({
    super.key,
    required this.index,
    required this.time,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;
    return Container(
      margin: EdgeInsets.fromLTRB(
        MediaQuery.of(context).size.width * 0.02,
        0,
        MediaQuery.of(context).size.width * 0.02,
        0,
      ),
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF5F5F5) : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Confirmed: $time',
            style: AppTypography.headerSemibold.copyWith(
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}