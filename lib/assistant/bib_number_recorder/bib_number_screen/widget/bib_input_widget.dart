import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../model/bib_data.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../core/theme/app_colors.dart';

class BibInputWidget extends StatelessWidget {
  final int index;
  final BibRecord record;
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
    if (record.flags['not_in_database'] == false && record.bibNumber.isNotEmpty) {
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
    if (record.flags['duplicate_bib_number']!) errors.add('Duplicate Bib Number');
    if (record.flags['not_in_database']!) errors.add('Runner not found');
    if (record.flags['low_confidence_score']!) errors.add('Low Confidence Score');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 16, color: Colors.red),
        const SizedBox(width: 8),
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
