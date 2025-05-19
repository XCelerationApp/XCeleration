import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../utils/enums.dart';
import '../../../assistant/race_timer/model/timing_record.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class ConflictHeader extends StatelessWidget {
  const ConflictHeader({
    super.key,
    required this.type,
    required this.conflictRecord,
    required this.startTime,
    required this.endTime,
  });
  final RecordType type;
  final TimingRecord conflictRecord;
  final String startTime;
  final String endTime;

  @override
  Widget build(BuildContext context) {
    final String title = type == RecordType.extraRunner
        ? 'Too Many Runner Times'
        : 'Missing Runner Times';
    final String description =
        '${type == RecordType.extraRunner ? 'There are more times recorded by the timing assistant than runners' : 'There are more runners than times recorded by the timing assistant'}. Please select or enter appropriate times between $startTime and $endTime to resolve the discrepancy between recorded times and runners.';
    final IconData icon =
        type == RecordType.extraRunner ? Icons.group_add : Icons.person_search;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.primaryColor, 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(AppColors.primaryColor, 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title at ${conflictRecord.elapsedTime}',
                  style: AppTypography.bodySemibold.copyWith(
                    color: AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.smallBodyRegular.copyWith(
                    color: ColorUtils.withOpacity(AppColors.primaryColor, 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmHeader extends StatelessWidget {
  const ConfirmHeader({
    super.key,
    required this.confirmRecord,
  });
  final TimingRecord confirmRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(Color.fromRGBO(76, 175, 80, 1.0), 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(Color.fromRGBO(76, 175, 80, 1.0), 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(Color.fromRGBO(0, 255, 0, 1.0), 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmed Results at ${confirmRecord.elapsedTime}',
                  style: AppTypography.bodySemibold.copyWith(
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These runner results have been confirmed',
                  style: AppTypography.smallBodyRegular.copyWith(
                    color: ColorUtils.withOpacity(Color.fromRGBO(76, 175, 80, 1.0), 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmationRecord extends StatelessWidget {
  const ConfirmationRecord(this.context, this.index, this.timeRecord,
      {super.key});
  final BuildContext context;
  final int index;
  final TimingRecord timeRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(Color.fromRGBO(76, 175, 80, 1.0), 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(Color.fromRGBO(76, 175, 80, 1.0), 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(Color.fromRGBO(76, 175, 80, 1.0), 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Confirmed',
                style: AppTypography.bodyRegular.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(Color.fromRGBO(0, 0, 0, 1.0), 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              timeRecord.elapsedTime,
              style: AppTypography.bodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
