import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../controller/merge_conflicts_controller.dart';

class TimeSelector extends StatelessWidget {
  const TimeSelector({
    super.key,
    required this.controller,
    required this.timeController,
    required this.manualController,
    required this.times,
    required this.conflictIndex,
    required this.manual,
  });
  final MergeConflictsController controller;
  final TextEditingController timeController;
  final TextEditingController? manualController;
  final List<String> times;
  final int conflictIndex;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final availableOptions = times
        .where((time) =>
            time == timeController.text ||
            !controller.selectedTimes[conflictIndex].contains(time))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: availableOptions.contains(timeController.text)
              ? timeController.text
              : null,
          hint: Text(
            timeController.text.isEmpty ? 'Select Time' : timeController.text,
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.darkColor,
            ),
          ),
          items: [
            if (manual)
              DropdownMenuItem<String>(
                value: 'manual_entry',
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.25,
                  child: TextField(
                    controller: manualController,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                    cursorColor: AppColors.primaryColor,
                    decoration: InputDecoration(
                      hintText: 'Enter time',
                      hintStyle: AppTypography.smallBodyRegular.copyWith(
                        color: Colors.grey[500],
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        final String previousValue = timeController.text;
                        timeController.text = value;
                        controller.updateSelectedTime(
                            conflictIndex, value, previousValue);
                      }
                    },
                  ),
                ),
              ),
            ...availableOptions.map((time) => DropdownMenuItem<String>(
                  value: time,
                  child: Text(
                    time,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                )),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == 'manual_entry') return;

            final previousValue = timeController.text;
            timeController.text = value;
            controller.updateSelectedTime(conflictIndex, value, previousValue);
            if (manualController != null) {
              manualController?.clear();
            }
          },
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.primaryColor,
            size: 28,
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ConfirmedTime extends StatelessWidget {
  const ConfirmedTime({
    super.key,
    required this.time,
  });
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
