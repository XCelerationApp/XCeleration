import 'package:flutter/material.dart';
import '../model/runner_record.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../utils/enums.dart';

class RunnerTimeRecordItem extends StatelessWidget {
  final RunnerRecord record;
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
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: record.textColor != null ? AppColors.confirmRunnerColor : null,
            ),
          ),
          Text(
            record.elapsedTime,
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
  final RunnerRecord record;
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
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18, 
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}

class ConflictRecordItem extends StatelessWidget {
  final RunnerRecord record;
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
            record.type == RecordType.missingRunner 
              ? 'Missing Runner at ${record.elapsedTime}'
              : 'Extra Runner at ${record.elapsedTime}',
            style: AppTypography.bodySemibold.copyWith(
              fontSize: 18,
              color: AppColors.redColor,
            ),
          ),
        ],
      ),
    );
  }
}
