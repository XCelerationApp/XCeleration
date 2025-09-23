import 'package:flutter/material.dart';
import '../../../../core/theme/typography.dart';
import '../model/bib_record.dart';
import '../controller/bib_number_controller.dart';

class BibInputWidget extends StatelessWidget {
  final int index;
  final BibNumberController controller;
  late final BibDatumRecord record;

  BibInputWidget({
    super.key,
    required this.index,
    required this.controller,
  }) {
    record = controller.bibRecords[index];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // if (!controller.isRecording) return;
        // controller.focusNodes[index].requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              child: _buildBibTextField(context),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (record.name!.isNotEmpty && !record.hasErrors)
                    _buildRunnerInfo()
                  else if (record.hasErrors)
                    _buildErrorText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBibTextField(BuildContext context) {
    return TextField(
      readOnly: !controller.isRecording,
      canRequestFocus: controller.isRecording,
      key: ValueKey('bibTextField_$index'),
      controller: controller.controllers[index],
      focusNode: controller.focusNodes[index],
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      style: AppTypography.titleRegular.copyWith(
        fontWeight: FontWeight.bold,
      ),
      onChanged: (value) {
        controller.handleBibNumber(value, index: index);
      },
      onSubmitted: (value) {
        if (controller.canAddBib) {
          controller.handleBibNumber('');
        }
      },
      decoration: InputDecoration(
        // labelText: 'Bib #',
        labelStyle: AppTypography.caption.copyWith(
          color: Colors.grey.shade700,
        ),
        hintText: 'Enter bib',
        hintStyle: AppTypography.bodyRegular.copyWith(
          color: Colors.grey.shade700,
        ),
        border: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: Colors.grey.shade600, // Darker gray when focused
            width: 1.5,
          ),
        ),
        enabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
      ),
    );
  }

  Widget _buildRunnerInfo() {
    if (record.flags.notInDatabase == false && record.bib.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show a visual indicator of successful match
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          Flexible(
            child: Text(
              '${record.name}, ${record.teamAbbreviation}',
              textAlign: TextAlign.center,
              style: AppTypography.bodyRegular,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildErrorText() {
    final errors = <String>[];
    if (record.flags.duplicateBibNumber) errors.add('Duplicate Bib Number');
    if (record.flags.notInDatabase) errors.add('Runner not found');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errors.isNotEmpty)
          Icon(Icons.error_outline, color: Colors.red, size: 16),
        if (errors.isNotEmpty) const SizedBox(width: 4),
        Text(
          errors.join(' • '),
          style: AppTypography.caption.copyWith(
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}
