import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../model/bib_records_provider.dart';
import '../../../../core/theme/typography.dart';

class BibInputWidget extends StatelessWidget {
  final int index;
  final RunnerRecord record;
  final Function(String, {List<double>? confidences, int? index})
      onBibNumberChanged;
  final Function() onSubmitted;

  const BibInputWidget({
    super.key,
    required this.index,
    required this.record,
    required this.onBibNumberChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final provider =
            Provider.of<BibRecordsProvider>(context, listen: false);
        provider.focusNodes[index].requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                  if (record.name.isNotEmpty && !record.hasErrors)
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
    final provider = Provider.of<BibRecordsProvider>(context);
    final index = this.index;
    
    // Use a more neutral gray color for the border
    final borderColor = Colors.grey.shade400;
    
    // Determine error styling based on flags
    final hasErrors = record.flags.notInDatabase || 
                     record.flags.duplicateBibNumber;
    
    return TextField(
      key: ValueKey('bibTextField_$index'),
      controller: provider.controllers[index],
      focusNode: provider.focusNodes[index],
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      style: TextStyle(
        fontSize: 20, // Smaller text size
        fontWeight: FontWeight.bold,
      ),
      onChanged: (value) {
        onBibNumberChanged(value, index: index);
      },
      onSubmitted: (value) {
        onSubmitted();
      },
      decoration: InputDecoration(
        labelText: 'Bib #',
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12, // Smaller label text
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0, // Smaller padding
          horizontal: 12.0, // Smaller padding
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0), // Smaller radius
          borderSide: BorderSide(
            color: borderColor,
            width: 1.0, // Thinner border
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: BorderSide(
            color: Colors.grey.shade600, // Darker gray when focused
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: BorderSide(
            color: borderColor.withOpacity(0.7),
            width: 1.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: BorderSide(
            color: hasErrors ? Colors.red : borderColor,
            width: 1.0,
          ),
        ),
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
              '${record.name}, ${record.school}',
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
    if (record.flags.lowConfidenceScore) errors.add('Low Confidence Score');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (errors.isNotEmpty)
          Icon(Icons.error_outline, color: Colors.red, size: 16),
        if (errors.isNotEmpty) const SizedBox(width: 4),
        Text(
          errors.join(' • '),
          style: AppTypography.bodyRegular.copyWith(
            color: Colors.red,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
