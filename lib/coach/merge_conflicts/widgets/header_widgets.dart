import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class ConflictHeader extends StatelessWidget {
  const ConflictHeader({
    super.key,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.offBy,
    this.removedCount = 0,
    this.enteredCount = 0,
  });
  final ConflictType type;
  final String startTime;
  final String endTime;
  final int? offBy;
  final int removedCount;
  final int enteredCount;

  @override
  Widget build(BuildContext context) {
    final String title = type == ConflictType.extraTime
        ? 'Extra Time${(offBy != null && offBy! > 1) ? 's' : ''} Detected'
        : 'Missing Time${(offBy != null && offBy! > 1) ? 's' : ''} Detected';
    final String description = type == ConflictType.extraTime
        ? 'There are more times than runners. Please select the extra time that should be removed from the results by clicking the X button next to it.'
        : 'There are more runners than times. Please enter a missing time to the correct runner by clicking the + button next to it.';

    // Create status text based on conflict type
    String? statusText;
    Color? statusColor;

    if (offBy != null) {
      if (type == ConflictType.extraTime) {
        final remaining = offBy! - removedCount;
        if (remaining > 0) {
          statusText =
              'Remove $remaining more time${remaining > 1 ? 's' : ''} ($removedCount/$offBy removed)';
          statusColor = Colors.orange;
        } else {
          statusText = 'Ready to resolve! ($removedCount/$offBy removed)';
          statusColor = Colors.green;
        }
      } else if (type == ConflictType.missingTime) {
        final remaining = offBy! - enteredCount;
        if (remaining > 0) {
          statusText =
              'Enter $remaining more time${remaining > 1 ? 's' : ''} ($enteredCount/$offBy entered)';
          statusColor = Colors.orange;
        } else {
          statusText = 'Ready to resolve! ($enteredCount/$offBy entered)';
          statusColor = Colors.green;
        }
      }
    }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title at $endTime',
                  style: AppTypography.bodySemibold.copyWith(
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              if (statusText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorUtils.withOpacity(statusColor!, 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ColorUtils.withOpacity(statusColor, 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: statusColor,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
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
    );
  }
}

class ConfirmHeader extends StatelessWidget {
  const ConfirmHeader({
    super.key,
    required this.confirmTime,
  });
  final String confirmTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(Colors.green, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(Colors.green, 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(Colors.green, 0.2),
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
                  'Confirmed Results at $confirmTime',
                  style: AppTypography.bodySemibold.copyWith(
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These runner results have been confirmed',
                  style: AppTypography.smallBodyRegular.copyWith(
                    color: ColorUtils.withOpacity(Colors.green, 0.8),
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
  final TimingDatum timeRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(Colors.green, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(Colors.green, 0.5),
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
                  color: ColorUtils.withOpacity(Colors.green, 0.2),
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
                  color: ColorUtils.withOpacity(Colors.black, 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              timeRecord.time,
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
