import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../model/results_record.dart';
import '../model/team_record.dart';
import 'package:xceleration/core/utils/color_utils.dart';

/// A generic widget that displays a collapsible list of items.
///
/// Callers supply a typed [headerBuilder] and [rowBuilder].
/// Use [CollapsibleIndividualResultsWidget] or [CollapsibleTeamResultsWidget]
/// for the pre-built race-result variants.
class CollapsibleResultsWidget<T> extends StatefulWidget {
  final List<T> results;
  final int initialVisibleCount;
  final Widget Function() headerBuilder;
  final Widget Function(T) rowBuilder;

  const CollapsibleResultsWidget({
    super.key,
    required this.results,
    required this.headerBuilder,
    required this.rowBuilder,
    this.initialVisibleCount = 5,
  });

  @override
  State<CollapsibleResultsWidget<T>> createState() =>
      _CollapsibleResultsWidgetState<T>();
}

class _CollapsibleResultsWidgetState<T>
    extends State<CollapsibleResultsWidget<T>> {
  bool isExpanded = false;

  void toggleExpansion() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return const Center(child: Text('No results to display'));
    }

    final displayResults = isExpanded
        ? widget.results
        : widget.results.take(widget.initialVisibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wrap the entire table (header + rows) in a single horizontal scroll
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.headerBuilder(),
              const SizedBox(height: 8),
              // Display results rows — inside a horizontal scroll view so a
              // vertical viewport (ListView) cannot be used here (unbounded
              // cross-axis width). Use a Column spread instead; the list is
              // always small (≤ initialVisibleCount visible at once).
              ...displayResults.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final backgroundColor = index % 2 == 0
                    ? Colors.transparent
                    : ColorUtils.withOpacity(Colors.grey, 0.05);

                return Container(
                  color: backgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: widget.rowBuilder(item),
                );
              }),
            ],
          ),
        ),

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
}

/// Pre-built [CollapsibleResultsWidget] variant for individual race results.
class CollapsibleIndividualResultsWidget extends StatelessWidget {
  final List<ResultsRecord> results;
  final int initialVisibleCount;

  const CollapsibleIndividualResultsWidget({
    super.key,
    required this.results,
    this.initialVisibleCount = 5,
  });

  static const int _nameCharacterLimit = 18;

  static String _truncateName(String name, {int limit = _nameCharacterLimit}) {
    if (name.length <= limit) return name;
    return '${name.substring(0, limit)}...';
  }

  static Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text('Place', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 150,
              child: Text('Name', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 70,
              child: Text('Team', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 80,
              child: Text('Time', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 70,
              child: Text('Pace/mi', style: AppTypography.bodySemibold)),
        ],
      ),
    );
  }

  static Widget _buildRow(ResultsRecord result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text('${result.place}', style: AppTypography.bodyRegular),
            ),
            SizedBox(
              width: 150,
              child: Text(_truncateName(result.name),
                  style: AppTypography.bodyRegular),
            ),
            SizedBox(
              width: 70,
              child: Text(_truncateName(result.teamAbbreviation, limit: 20),
                  style: AppTypography.bodyRegular),
            ),
            SizedBox(
              width: 80,
              child: Text(result.formattedFinishTime,
                  style: AppTypography.bodyRegular),
            ),
            SizedBox(
              width: 70,
              child: Text(
                  result.formattedPacePerMile.isEmpty
                      ? '-'
                      : result.formattedPacePerMile,
                  style: AppTypography.bodyRegular),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleResultsWidget<ResultsRecord>(
      results: results,
      initialVisibleCount: initialVisibleCount,
      headerBuilder: _buildHeader,
      rowBuilder: _buildRow,
    );
  }
}

/// Pre-built [CollapsibleResultsWidget] variant for team race results.
class CollapsibleTeamResultsWidget extends StatelessWidget {
  final List<TeamRecord> results;
  final int initialVisibleCount;

  const CollapsibleTeamResultsWidget({
    super.key,
    required this.results,
    this.initialVisibleCount = 5,
  });

  static Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text('Place', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 70,
              child: Text('Team', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 150,
              child: Text('Scorers', style: AppTypography.bodySemibold)),
          SizedBox(
              width: 50,
              child: Text('Score', style: AppTypography.bodySemibold)),
        ],
      ),
    );
  }

  static Widget _buildRow(TeamRecord team) {
    final scorerPlaces = team.scorers.isNotEmpty
        ? [
            ...team.scorers.map((scorer) => scorer.place.toString()),
            if (team.topSeven.length > 5)
              '(${team.topSeven.sublist(5, team.topSeven.length).map((runner) => runner.place.toString()).join(', ')})'
          ].join(', ')
        : 'N/A';

    final abbrev = team.team.abbreviation ?? 'N/A';
    final truncatedAbbrev =
        abbrev.length <= 15 ? abbrev : '${abbrev.substring(0, 15)}...';

    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(team.place != null ? '${team.place}' : '-',
              style: AppTypography.bodyRegular),
        ),
        SizedBox(
          width: 70,
          child: Text(truncatedAbbrev, style: AppTypography.bodyRegular),
        ),
        SizedBox(
          width: 150,
          child: Text(scorerPlaces, style: AppTypography.bodyRegular),
        ),
        SizedBox(
          width: 50,
          child: Text('${team.score != 0 ? team.score : 'N/A'}',
              style: AppTypography.bodyRegular),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleResultsWidget<TeamRecord>(
      results: results,
      initialVisibleCount: initialVisibleCount,
      headerBuilder: _buildHeader,
      rowBuilder: _buildRow,
    );
  }
}
