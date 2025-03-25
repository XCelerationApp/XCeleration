import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/results_record.dart';

class IndividualResultsWidget extends StatelessWidget {
  final List<ResultsRecord> individualResults;
  
  const IndividualResultsWidget({
    super.key,
    required this.individualResults,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Individual Results',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: individualResults.length,
          itemBuilder: (context, index) {
            final runner = individualResults[index];
            return ListTile(
              title: Text(
                '${index + 1}. ${runner.name} (${runner.school})',
                style: AppTypography.bodyRegular,
              ),
              subtitle: Text(
                'Time: ${runner.formattedFinishTime} | Grade: ${runner.grade} | Bib: ${runner.bib}',
                style: AppTypography.bodyRegular,
              ),
            );
          },
        ),
      ],
    );
  }
}