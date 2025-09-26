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
      child: _buildRecordContent(context),
    );
  }

  Widget _buildRecordContent(BuildContext context) {
    final hasPlace = uiRecord.place != null;
    final displayText = _getDisplayText();

    return Row(
      mainAxisAlignment:
          hasPlace ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
      children: [
        if (hasPlace)
          Text(
            uiRecord.place.toString(),
            style: AppTypography.headerSemibold.copyWith(
              color: uiRecord.textColor,
            ),
          ),
        Text(
          displayText,
          style: AppTypography.headerSemibold.copyWith(
            color: uiRecord.textColor,
          ),
        ),
      ],
    );
  }

  String _getDisplayText() {
    switch (uiRecord.type) {
      case RecordType.confirmRunner:
        return 'Confirmed: ${uiRecord.time}';
      default:
        return uiRecord.time;
    }
  }
}
