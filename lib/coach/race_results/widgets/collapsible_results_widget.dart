import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
        // The columns share the screen's width rather than scrolling
        // sideways, so the score and time are never off the edge.
        widget.headerBuilder(),
        const Divider(height: 1, color: AppColors.lightColor),
        ...displayResults.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final backgroundColor = index % 2 == 0
              ? Colors.transparent
              : ColorUtils.withOpacity(Colors.grey, 0.05);

          return Container(
            color: backgroundColor,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: widget.rowBuilder(item),
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
}

/// The width of the place column in both results tables.
const double _placeWidth = 52;

TextStyle get _headerStyle =>
    AppTypography.captionBold.copyWith(color: AppColors.mediumColor);

const _tabular = [FontFeature.tabularFigures()];

/// "Place" over the narrow place column, shrunk rather than wrapped at a
/// large text size.
class _PlaceHeader extends StatelessWidget {
  const _PlaceHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _placeWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('Place', style: _headerStyle),
      ),
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

  static Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const _PlaceHeader(),
          Expanded(child: Text('Runner', style: _headerStyle)),
          Text('Time', style: _headerStyle),
        ],
      ),
    );
  }

  static Widget _buildRow(ResultsRecord result) {
    final pace = result.formattedPacePerMile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _placeWidth,
          child: Text('${result.place}', style: AppTypography.bodySemibold),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.name,
                  style: AppTypography.bodyRegular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(result.teamAbbreviation,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.mediumColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(result.formattedFinishTime,
                style: AppTypography.bodySemibold
                    .copyWith(fontFeatures: _tabular)),
            if (pace.isNotEmpty)
              Text('$pace/mi',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.mediumColor, fontFeatures: _tabular)),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const _PlaceHeader(),
          Expanded(child: Text('Team', style: _headerStyle)),
          Text('Score', style: _headerStyle),
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
        : 'No scorers';

    final abbrev = team.team.abbreviation ?? 'N/A';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _placeWidth,
          child: Text(team.place != null ? '${team.place}' : '-',
              style: AppTypography.bodySemibold),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(abbrev,
                  style: AppTypography.bodyRegular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text('Scorers: $scorerPlaces',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.mediumColor)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('${team.score != 0 ? team.score : '-'}',
            style: AppTypography.bodySemibold
                .copyWith(fontFeatures: _tabular)),
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
