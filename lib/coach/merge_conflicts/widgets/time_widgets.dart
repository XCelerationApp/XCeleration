import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/enums.dart';
import '../../../core/theme/typography.dart';
import '../controller/merge_conflicts_controller.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class TimeSelector extends StatefulWidget {
  const TimeSelector({
    super.key,
    required this.controller,
    required this.timeController,
    required this.manualController,
    required this.times,
    required this.conflictIndex,
    required this.manual,
    this.chunkType,
  });
  final RecordType? chunkType;
  final MergeConflictsController controller;
  final TextEditingController timeController;
  final TextEditingController? manualController;
  final List<String> times;
  final int conflictIndex;
  final bool manual;
  
  @override
  State<TimeSelector> createState() => _TimeSelectorState();
}

class _TimeSelectorState extends State<TimeSelector> {
  @override
  void initState() {
    super.initState();
    if (widget.manualController != null) {
      widget.manualController!.addListener(() {
        // This ensures that changes to the manual controller are picked up
        if (mounted) setState(() {});
      });
    }
  }
  
  // Check if THIS specific selector is in manual mode
  bool get isThisManual {
    final selectedValue = widget.controller.selectedTimes[widget.conflictIndex];
    return selectedValue == 'manual_entry';
  }
  
  // Check if any OTHER selector is in manual mode
  bool get isManualUsedElsewhere {
    return widget.controller.selectedTimes.entries.any((entry) =>
      entry.key != widget.conflictIndex && entry.value == 'manual_entry');
  }
  
  List<String> get availableOptions {
    final selectedTimes = widget.controller.selectedTimes;
    // Gather all values that are selected (excluding this slot)
    final usedTimes = selectedTimes.entries
        .where((entry) => entry.key != widget.conflictIndex && entry.value != 'manual_entry')
        .map((entry) => entry.value)
        .toSet();
    // Only show times not already selected elsewhere, or the current value
    return widget.times.where((time) =>
      time == widget.timeController.text || !usedTimes.contains(time)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    // If in manual mode for this slot, show TextField
    if (isThisManual) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.withOpacity(Colors.black, 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            controller: widget.manualController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              hintText: 'Enter time (e.g. 4:10.45)',
              hintStyle: AppTypography.smallBodyRegular.copyWith(
                color: Colors.grey[500],
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (val) {
              final previousValue = widget.timeController.text;
              widget.timeController.text = val;
              widget.controller.updateSelectedTime(widget.conflictIndex, val, previousValue);
              setState(() {});
            }
          ),
        ),
      );
    }

    // Otherwise, show dropdown with manual entry option if allowed
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.withOpacity(Colors.black, 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: availableOptions.contains(widget.timeController.text)
              ? widget.timeController.text
              : null,
          hint: Text(
            widget.timeController.text.isEmpty ? 'Select Time' : widget.timeController.text,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.darkColor,
            ),
          ),
          items: [
            // Show all available times (they can be reused)
            ...availableOptions.map((time) => DropdownMenuItem<String>(
                  value: time,
                  child: Text(
                    time,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                )),
            // Add manual entry option if allowed and not used elsewhere
            if (widget.manual && !isManualUsedElsewhere)
              DropdownMenuItem<String>(
                value: 'manual_entry',
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter manually',
                            style: AppTypography.smallBodySemibold.copyWith(
                              color: AppColors.darkColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == 'manual_entry') {
              // Switch to manual entry mode for ONLY this slot
              widget.controller.selectedTimes[widget.conflictIndex] = 'manual_entry';
              widget.timeController.clear();
              if (widget.manualController != null) {
                widget.manualController!.clear();
              }
              setState(() {});
              return;
            }
            
            // Handle regular dropdown selection
            final previousValue = widget.timeController.text;
            widget.timeController.text = value;
            widget.controller.updateSelectedTime(widget.conflictIndex, value, previousValue);
            
            // Clear manual controller and store the selected time value
            if (widget.manualController != null) {
              widget.manualController!.clear();
            }
            // widget.controller.selectedTimes[widget.conflictIndex] = value;
            
            setState(() {});
          },
          dropdownColor: Colors.white,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppColors.primaryColor,
            size: 28,
          ),
          isExpanded: true,
          borderRadius: BorderRadius.circular(5),
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
