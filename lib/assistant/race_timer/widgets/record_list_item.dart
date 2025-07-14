import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/conflict.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';


class RunnerTimeRecordItem extends StatelessWidget {
  final int index;
  final BuildContext context;
  final String time;
  final Conflict? conflict;
  final int place;
  final Color textColor;

  const RunnerTimeRecordItem({
    super.key,
    required this.index,
    required this.time,
    this.conflict,
    required this.place,
    required this.textColor,
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
            '$place',
            style: AppTypography.headerSemibold.copyWith(
              color: textColor,
            ),
          ),
          Text(
            time,
            style: AppTypography.headerSemibold.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
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

class ConflictRecordItem extends StatelessWidget {
  final int index;
  final BuildContext context;
  final String time;
  final Conflict conflict;

  const ConflictRecordItem({
    super.key,
    required this.index,
    required this.time,
    required this.conflict,
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
            conflict.type == ConflictType.missingTime
                ? 'Missing Time at $time'
                : 'Extra Time at $time',
            style: AppTypography.headerSemibold.copyWith(
              color: AppColors.redColor,
            ),
          ),
        ],
      ),
    );
  }
}
