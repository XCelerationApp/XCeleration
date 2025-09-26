import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import '../../../core/components/button_components.dart';
import '../../../core/components/dialog_utils.dart';
import '../controller/bib_number_controller.dart';

class RaceControlsWidget extends StatelessWidget {
  final BibNumberController controller;

  const RaceControlsWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRaceControlButton(context),
        if (!controller.isRecording && controller.countNonEmptyBibNumbers() > 0)
          _buildShareButton(context),
        _buildLogButton(context),
      ],
    );
  }

  Widget _buildRaceControlButton(BuildContext context) {
    final buttonText = controller.isRecording
        ? 'Stop'
        : controller.bibRecords.isNotEmpty
            ? 'Resume'
            : 'Start';
    final buttonColor = controller.isRecording ? Colors.red : Colors.green;

    return CircularButton(
      text: buttonText,
      color: buttonColor,
      fontSize: controller.isRecording ? 18 : 16,
      fontWeight: FontWeight.w600,
      onPressed: controller.toggleRecording,
    );
  }

  Widget _buildShareButton(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ActionButton(
              height: 70,
              text: 'Share Bibs',
              icon: Icons.share,
              iconSize: 18,
              fontSize: 18,
              textColor: AppColors.mediumColor,
              backgroundColor: AppColors.backgroundColor,
              borderColor: AppColors.mediumColor,
              fontWeight: FontWeight.w500,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              borderRadius: 30,
              isPrimary: false,
              onPressed: () => controller.showShareBibNumbersPopup(context),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogButton(BuildContext context) {
    return CircularButton(
      text: (controller.bibRecords.isEmpty || controller.isRecording)
          ? 'Add'
          : 'Clear',
      color: ((controller.isRecording && controller.canAddBib) ||
              (!controller.isRecording && controller.bibRecords.isNotEmpty))
          ? const Color(0xFF777777)
          : const Color(0xFF777777).withAlpha((0.5 * 255).round()),
      fontSize: 18,
      fontWeight: FontWeight.w600,
      onPressed: () async {
        if (controller.bibRecords.isNotEmpty && !controller.isRecording) {
          final bool confirmation = await DialogUtils.showConfirmationDialog(
              context,
              title: 'Confirm Deletion',
              content: 'Are you sure you want to clear all the recorded bibs?');
          if (confirmation) {
            controller.clearBibRecords();
          }
        } else if (controller.isRecording && controller.canAddBib) {
          await controller.addBib();
        } else if (!controller.isRecording && controller.bibRecords.isEmpty) {
          // Show message when Add button is clicked but race is not running
          await DialogUtils.showMessageDialog(
            context,
            title: 'Race Not Started',
            message: 'Please start the race before adding bib numbers',
          );
        }
      },
    );
  }
}
