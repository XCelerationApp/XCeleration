import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/results_record.dart';
import '../model/team_record.dart';
import 'package:xceleration/core/utils/color_utils.dart';

/// A widget that displays a collapsible list of race results
/// Can handle both individual results (ResultsRecord) and team results (TeamRecord)
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
  late List<dynamic> displayResults;

  @override
  void initState() {
    super.initState();
    _updateDisplayResults();
  }

  void _updateDisplayResults() {
    displayResults = isExpanded
        ? widget.results
        : widget.results.take(widget.initialVisibleCount).toList();
  }

  void toggleExpansion() {
    setState(() {
      isExpanded = !isExpanded;
      _updateDisplayResults();
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Display the appropriate header
        isTeamResults
            ? _buildTeamResultsHeader()
            : _buildIndividualResultsHeader(),

        const SizedBox(height: 8),

        // Display results rows
        ...displayResults.map((item) {
          final index = displayResults.indexOf(item);
          // Use subtle alternate row colors for better readability
          final backgroundColor = index % 2 == 0
              ? Colors.transparent
              : ColorUtils.withOpacity(Colors.grey, 0.05);

          return Container(
            color: backgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: isTeamResults
                ? _buildTeamResultRow(item as TeamRecord)
                : _buildIndividualResultRow(item as ResultsRecord),
          );
        }),

        // "See more"/"See less" button if needed
        if (widget.results.length > widget.initialVisibleCount)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Align(
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
          ),
      ],
    );
  }

  Widget _buildIndividualResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
              width: 50,
              child: Text('Place', style: AppTypography.bodySemibold)),
          Expanded(child: Text('Name', style: AppTypography.bodySemibold)),
          Expanded(child: Text('Team', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 70,
              child: Text('Time', style: AppTypography.bodySemibold)),
        ],
      ),
    );
  }

  Widget _buildTeamResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
              width: 50,
              child: Text('Place', style: AppTypography.bodySemibold)),
          Expanded(
              flex: 2, child: Text('Team', style: AppTypography.bodySemibold)),
          Expanded(
              flex: 3,
              child: Text('Scorers', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 70,
              child: Text('Score', style: AppTypography.bodySemibold)),
        ],
      ),
    );
  }

  Widget _buildIndividualResultRow(ResultsRecord result) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text('${result.place}', style: AppTypography.bodyRegular),
        ),
        Expanded(
            child: Text(result.name,
                style: AppTypography.bodyRegular,
                overflow: TextOverflow.ellipsis)),
        Expanded(
            child: Text(result.teamAbbreviation,
                style: AppTypography.bodyRegular,
                overflow: TextOverflow.ellipsis)),
        SizedBox(
          width: 70,
          child: Text(result.formattedFinishTime,
              style: AppTypography.bodyRegular),
        ),
      ],
    );
  }

  Widget _buildTeamResultRow(TeamRecord team) {
    // Format the scorer places as a string (e.g., "1, 4, 7, 12, 15")
    final scorerPlaces = team.scorers.isNotEmpty
        ? [
            ...team.scorers.map((scorer) => scorer.place.toString()),
            if (team.topSeven.length > 5)
              '(${team.topSeven.sublist(5, team.topSeven.length).map((runner) => runner.place.toString()).join(', ')})'
          ].join(', ')
        : 'N/A';

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(team.place != null ? '${team.place}' : '-',
              style: AppTypography.bodyRegular),
        ),
        Expanded(
            flex: 2,
            child: Text(team.teamAbbreviation,
                style: AppTypography.bodyRegular,
                overflow: TextOverflow.ellipsis)),
        Expanded(
            flex: 3,
            child: Text(scorerPlaces,
                style: AppTypography.bodyRegular,
                overflow: TextOverflow.ellipsis)),
        SizedBox(
          width: 70,
          child: Text('${team.score != 0 ? team.score : 'N/A'}',
              style: AppTypography.bodyRegular),
        ),
      ],
    );
  }
}
