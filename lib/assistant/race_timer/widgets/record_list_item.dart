import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';
import '../model/ui_record.dart';

class RecordListItem extends StatelessWidget {
  final UIRecord uiRecord;
  final int index;

  const RecordListItem({
    super.key,
    required this.uiRecord,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isEven = index % 2 == 0;
    return Container(
      decoration: BoxDecoration(
        color: isEven ? AppColors.surfaceColor : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.lg),
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
            fontFeatures: const [FontFeature.tabularFigures()],
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
