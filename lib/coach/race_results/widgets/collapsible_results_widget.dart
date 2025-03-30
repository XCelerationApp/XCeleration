import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/results_record.dart';
import '../model/team_record.dart';

class CollapsibleResultsWidget extends StatefulWidget {
  final List<dynamic> results;
  final int initialVisibleCount;
  const CollapsibleResultsWidget(
      {super.key, required this.results, this.initialVisibleCount = 5});

  @override
  State<CollapsibleResultsWidget> createState() =>
      _CollapsibleResultsWidgetState();
}

class _CollapsibleResultsWidgetState extends State<CollapsibleResultsWidget> {
  bool isExpanded = false;

  List<dynamic> displayResults = [];

  @override
  void initState() {
    super.initState();
    displayResults = widget.results.take(widget.initialVisibleCount).toList();
  }

  void toggleExpansion() {
    setState(() {
      isExpanded = !isExpanded;
      displayResults = isExpanded
          ? widget.results
          : widget.results.take(widget.initialVisibleCount).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if results list is empty
    if (widget.results.isEmpty) {
      return const Center(child: Text('No results to display'));
    }

    // Determine the type of results we're displaying
    bool isTeamResults = widget.results.first is TeamRecord;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: isTeamResults
              ? _buildTeamResultsHeader()
              : _buildIndividualResultsHeader(),
        ),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: displayResults.length,
          itemBuilder: (context, index) {
            final item = displayResults[index];
            // Use subtle alternate row colors for better readability
            final backgroundColor = index % 2 == 0
                ? Colors.transparent
                : Colors.grey.withOpacity(0.05);

            return Container(
              color: backgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: isTeamResults
                  ? _buildTeamResultRow(item as TeamRecord)
                  : _buildIndividualResultRow(item as ResultsRecord),
            );
          },
        ),
        if (widget.results.length > widget.initialVisibleCount) ...[
          const SizedBox(height: 16),
          Container(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: toggleExpansion,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: Text(
                isExpanded ? 'See Less' : 'See More',
                style: AppTypography.smallBodyRegular,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIndividualResultsHeader() {
    return const Row(
      children: [
        SizedBox(
            width: 50, child: Text('Place', style: AppTypography.bodySemibold)),
        Expanded(
            flex: 1, child: Text('Name', style: AppTypography.bodySemibold)),
        Expanded(
            flex: 1, child: Text('School', style: AppTypography.bodySemibold)),
        Expanded(
            flex: 1, child: Text('Time', style: AppTypography.bodySemibold)),
      ],
    );
  }

  Widget _buildTeamResultsHeader() {
    return const Row(
      children: [
        SizedBox(
            width: 50, child: Text('Place', style: AppTypography.bodySemibold)),
        Expanded(
            flex: 1, child: Text('School', style: AppTypography.bodySemibold)),
        Expanded(
            flex: 1, child: Text('Score', style: AppTypography.bodySemibold)),
        Expanded(
            flex: 2,
            child: Text('Scorer Places', style: AppTypography.bodySemibold)),
      ],
    );
  }

  Widget _buildIndividualResultRow(ResultsRecord runner) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            '${runner.place}',
            style: AppTypography.bodyRegular,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            runner.name,
            style: AppTypography.bodyRegular,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            runner.school,
            style: AppTypography.bodyRegular,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            runner.formattedFinishTime,
            style: AppTypography.bodyRegular,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamResultRow(TeamRecord team) {
    // Format the scorer places as a string (e.g., "1, 4, 7, 12, 15")
    final scorerPlaces = team.scorers.isEmpty
        ? 'N/A'
        : team.scorers.map((scorer) => scorer.place.toString()).join(', ');

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            team.place?.toString() ?? '-',
            style: AppTypography.bodyRegular,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            team.school,
            style: AppTypography.bodyRegular,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            team.score.toString(),
            style: AppTypography.bodyRegular,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            scorerPlaces,
            style: AppTypography.bodyRegular,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
