import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
  });
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
  
  void _showManualEntryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Enter Time Manually',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.darkColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: widget.manualController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Enter time (e.g. 10.45)',
              hintStyle: AppTypography.smallBodyRegular.copyWith(
                color: Colors.grey[500],
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (widget.manualController?.text.isNotEmpty == true) {
                  final String previousValue = widget.timeController.text;
                  widget.timeController.text = widget.manualController!.text;
                  widget.controller.updateSelectedTime(
                    widget.conflictIndex,
                    widget.manualController!.text,
                    previousValue,
                  );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final availableOptions = widget.times
        .where((time) =>
            time == widget.timeController.text ||
            !widget.controller.selectedTimes[widget.conflictIndex].contains(time))
        .toList();

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
            if (widget.manual)
              DropdownMenuItem<String>(
                value: 'manual_entry',
                child: Row(
                  children: [
                    const Icon(Icons.edit, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Enter manually',
                      style: AppTypography.smallBodySemibold.copyWith(
                        color: AppColors.darkColor,
                      ),
                    ),
                  ],
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
            if (value == 'manual_entry') {
              // Show manual entry dialog instead of inline editing
              _showManualEntryDialog(context);
              return;
            }

            final previousValue = widget.timeController.text;
            widget.timeController.text = value;
            widget.controller.updateSelectedTime(widget.conflictIndex, value, previousValue);
            if (widget.manualController != null) {
              widget.manualController?.clear();
            }
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
