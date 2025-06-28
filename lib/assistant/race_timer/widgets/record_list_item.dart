import 'package:flutter/material.dart';
import '../../../shared/models/time_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';

class RunnerTimeRecordItem extends StatelessWidget {
  final TimeRecord record;
  final int index;
  final BuildContext context;

  const RunnerTimeRecordItem({
    super.key,
    required this.record,
    required this.index,
    required this.context,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${record.place ?? ''}',
            style: AppTypography.headerSemibold.copyWith(
              color: record.textColor != null
                  ? AppColors.confirmRunnerColor
                  : null,
            ),
          ),
          Text(
            record.elapsedTime,
            style: AppTypography.headerSemibold.copyWith(
              color: record.conflict == null
                  ? (record.isConfirmed == true
                      ? AppColors.confirmRunnerColor
                      : null)
                  : (record.conflict!.type != RecordType.confirmRunner
                      ? AppColors.redColor
                      : AppColors.confirmRunnerColor),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmationRecordItem extends StatelessWidget {
  final TimeRecord record;
  final int index;
  final BuildContext context;

  const ConfirmationRecordItem({
    super.key,
    required this.record,
    required this.index,
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
            'Confirmed: ${record.elapsedTime}',
            style: AppTypography.headerSemibold.copyWith(
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}

class ConflictRecordItem extends StatelessWidget {
  final TimeRecord record;
  final int index;
  final BuildContext context;

  const ConflictRecordItem({
    super.key,
    required this.record,
    required this.index,
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
            record.type == RecordType.missingTime
                ? 'Missing Time at ${record.elapsedTime}'
                : 'Extra Time at ${record.elapsedTime}',
            style: AppTypography.headerSemibold.copyWith(
              color: AppColors.redColor,
            ),
          ),
        ],
      ),
    );
  }
}
