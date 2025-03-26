import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../controller/share_race_controller.dart';
import '../widgets/share_format_selection_widget.dart';
import '../../../utils/enums.dart';


class ShareSheetScreen extends StatefulWidget {
  final ShareRaceController controller;

  const ShareSheetScreen({
    super.key,
    required this.controller,
  });

  @override
  State<ShareSheetScreen> createState() => _ShareSheetScreenState();
}

class _ShareSheetScreenState extends State<ShareSheetScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
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
            selected: {_selectedFormat},
            onSelectionChanged: (Set<ResultFormat> newSelection) {
              setState(() => _selectedFormat = newSelection.first);
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
        ),
        const SizedBox(height: 32),
        
        ShareFormatSelectionWidget(
          controller: widget.controller,
        ),
      ],
    );
  }
}
