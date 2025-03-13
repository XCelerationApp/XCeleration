import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../model/bib_records_provider.dart';
import '../../../../../core/theme/typography.dart';

class BibInputWidget extends StatelessWidget {
  final int index;
  final RunnerRecord record;
  final Function(String, {List<double>? confidences, int? index}) onBibNumberChanged;
  final Function() onSubmitted;

  const BibInputWidget({
    Key? key,
    required this.index,
    required this.record,
    required this.onBibNumberChanged,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final provider = Provider.of<BibRecordsProvider>(context, listen: false);
        provider.focusNodes[index].requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
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
              width: 60,
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
    return TextField(
      focusNode: provider.focusNodes[index],
      controller: provider.controllers[index],
      keyboardType: TextInputType.number,
      style: AppTypography.bodyRegular,
      textAlign: TextAlign.start,
      decoration: InputDecoration(
        labelText: 'Bib #',
        labelStyle: AppTypography.bodyRegular,
        border: const OutlineInputBorder(),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onSubmitted: (_) async {
        await onSubmitted();
      },
      onChanged: (value) => onBibNumberChanged(value, index: index),
      keyboardAppearance: Brightness.light,
    );
  }

  Widget _buildRunnerInfo() {
    if (record.flags.notInDatabase == false && record.bib.isNotEmpty) {
      return Text(
        '${record.name}, ${record.school}',
        textAlign: TextAlign.center,
        style: AppTypography.bodyRegular,
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
        if (errors.isNotEmpty)
          const SizedBox(width: 4),
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
