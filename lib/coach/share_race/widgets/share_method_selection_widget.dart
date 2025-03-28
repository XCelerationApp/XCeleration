import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/enums.dart';
import '../controller/share_race_controller.dart';


class ShareMethodSelectionWidget extends StatelessWidget {
  final ShareRaceController controller;

  const ShareMethodSelectionWidget({
    super.key,
    required this.controller,
  });
  
  @override
  Widget build(BuildContext context) {
    return  Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.unselectedRoleTextColor,
          width: 1,
        ),
      ),
      child: SegmentedButton<ResultFormat>(
        selectedIcon: const Icon(
          Icons.check,
          color: AppColors.unselectedRoleColor,
        ),
        segments: const [
          ButtonSegment<ResultFormat>(
            value: ResultFormat.plainText,
            label: Center(
              child: Text(
                'Plain Text',
                style: TextStyle(fontSize: 16, height: 1.2),
              ),
            ),
          ),
          ButtonSegment<ResultFormat>(
            value: ResultFormat.googleSheet,
            label: Center(
              child: Text(
                'Google Sheet',
                style: TextStyle(fontSize: 16, height: 1.2),
              ),
            ),
          ),
          ButtonSegment<ResultFormat>(
            value: ResultFormat.pdf,
            label: Center(
              child: Text(
                'PDF',
                style: TextStyle(fontSize: 16, height: 1.2),
              ),
            ),
          ),
        ],
        selected: {controller.selectedFormat},
        onSelectionChanged: (Set<ResultFormat> newSelection) {
          controller.selectedFormat = newSelection.first;
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) => 
            states.contains(WidgetState.selected) 
              ? AppColors.primaryColor 
              : AppColors.backgroundColor
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
            states.contains(WidgetState.selected)
              ? AppColors.unselectedRoleColor
              : AppColors.unselectedRoleTextColor
          ),
        ),
      ),
    );
  }
}