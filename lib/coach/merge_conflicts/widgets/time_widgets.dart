import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
    final availableOptions = times.where((time) => 
      time == timeController.text || !controller.selectedTimes[conflictIndex].contains(time)
    ).toList();

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
          value: availableOptions.contains(timeController.text) ? timeController.text : null,
          hint: Text(
            timeController.text.isEmpty ? 'Select Time' : timeController.text,
            style: TextStyle(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w500,
              fontSize: 15,
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
                    style: TextStyle(
                      color: AppColors.darkColor,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: AppColors.primaryColor,
                    decoration: InputDecoration(
                      hintText: 'Enter time',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        final String previousValue = timeController.text;
                        timeController.text = value;
                        controller.updateSelectedTime(conflictIndex, value, previousValue);
                      }
                    },
                  ),
                ),
              ),
            ...availableOptions.map((time) => DropdownMenuItem<String>(
              value: time,
              child: Text(
                time,
                style: TextStyle(
                  color: AppColors.darkColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
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
            style: TextStyle(
              color: AppColors.darkColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
