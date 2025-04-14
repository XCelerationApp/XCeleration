import 'package:flutter/material.dart';
import 'package:xcelerate/core/theme/app_colors.dart';
import 'package:xcelerate/core/theme/typography.dart';
import '../../../core/components/textfield_utils.dart';
import '../controller/race_screen_controller.dart';

class CompetingTeamsField extends StatelessWidget {
  final RaceScreenController controller;
  final StateSetter setSheetState;
  final ValueChanged<String>? onChanged;

  const CompetingTeamsField({
    required this.controller,
    required this.setSheetState,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Competing Teams',
            style: AppTypography.bodySemibold,
          ),
        ),
        if (controller.teamsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              controller.teamsError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ...controller.teamControllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController textController = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: buildTextField(
                    context: context,
                    controller: textController,
                    hint: 'Team name',
                    onChanged: (value) {
                      setSheetState(() {
                        controller.teamsError = controller.teamControllers
                                .every((textController) =>
                                    textController.text.trim().isEmpty)
                            ? 'Please enter in team name'
                            : null;
                      });
                      if (onChanged != null) onChanged!(value);
                    },
                    setSheetState: setSheetState,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () =>
                      controller.showColorPicker(setSheetState, textController),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: controller.teamColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.1 * 255).round()),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                if (controller.teamControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () {
                      setSheetState(() {
                        controller.teamControllers.removeAt(index);
                        controller.teamColors.removeAt(index);
                      });
                      if (onChanged != null) onChanged!("");
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            setSheetState(() {
              controller.addTeamField();
            });
            if (onChanged != null) onChanged!("");
          },
          icon: const Icon(Icons.add_circle_outline,
              color: AppColors.primaryColor),
          label: Text(
            'Add Another Team',
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.primaryColor),
            ),
          ),
        ),
      ],
    );
  }
}
