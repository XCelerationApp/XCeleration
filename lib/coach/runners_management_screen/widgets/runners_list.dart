import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import 'list_titles.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';
import 'runner_list_item.dart';
import 'team_header_tile.dart';

// Height of the TeamHeaderTile row: 8+8 vertical padding + 20px line height.
const double _kHeaderExtent = 36.0;
// Height of the ListTitles row: 8+8 vertical padding + ~16px line height.
const double _kTitlesExtent = 32.0;

class RunnersList extends StatefulWidget {
  const RunnersList({super.key, required this.controller});

  final RunnersManagementController controller;

  @override
  State<RunnersList> createState() => _RunnersListState();
}

class _RunnersListState extends State<RunnersList> {
  final Map<int, bool> _expanded = {};
  Future<Map<Team, List<RaceRunner>>>? _filteredFuture;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _filteredFuture = widget.controller.filteredSearchResults;
  }

  @override
  void didUpdateWidget(RunnersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      setState(() {
        _filteredFuture = widget.controller.filteredSearchResults;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {
      _filteredFuture = widget.controller.filteredSearchResults;
    });
  }

  bool _isExpanded(Team team) => _expanded[team.teamId ?? -1] ?? true;

  void _toggleExpanded(Team team) {
    setState(() {
      _expanded[team.teamId ?? -1] = !_isExpanded(team);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      );
    }

    return FutureBuilder<Map<Team, List<RaceRunner>>>(
      future: _filteredFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Could not load runners',
                  style: AppTypography.titleSemibold.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          );
        }

        final teamMap = snapshot.requireData;
        if (teamMap.isEmpty) return _EmptyState(controller: widget.controller);
        return _buildList(context, teamMap);
      },
    );
  }

  Widget _buildList(BuildContext context, Map<Team, List<RaceRunner>> teamMap) {
    final teams = teamMap.keys.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    final borderColor = AppColors.mediumColor.withValues(alpha: AppOpacity.medium);
    final cardRadius = Radius.circular(AppBorderRadius.md);

    final slivers = <Widget>[
      const SliverPadding(padding: EdgeInsets.only(top: AppSpacing.sm)),
    ];

    for (final team in teams) {
      final raceRunners = teamMap[team] ?? [];
      final expanded = _isExpanded(team);
      final hasRunners = raceRunners.isNotEmpty;
      final showTitles = expanded && hasRunners;
      // When collapsed or empty: full card rounding on the header.
      // When expanded with runners: header is the top half — round top corners only.
      final headerIsFullCard = !expanded || !hasRunners;

      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _TeamSectionHeaderDelegate(
            team: team,
            runnerCount: raceRunners.length,
            controller: widget.controller,
            isExpanded: expanded,
            showTitles: showTitles,
            headerIsFullCard: headerIsFullCard,
            borderColor: borderColor,
            cardRadius: cardRadius,
            onToggleExpand: () => _toggleExpanded(team),
            onAddRunner: () =>
                widget.controller.showAddRunnerChoiceSheet(context, team),
            isViewMode: widget.controller.isViewMode,
          ),
        ),
      );

      // Content: bottom half of the card, or spacing gap when collapsed.
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: expanded
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      border: Border(
                        bottom: BorderSide(color: borderColor),
                        left: BorderSide(color: borderColor),
                        right: BorderSide(color: borderColor),
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: cardRadius,
                        bottomRight: cardRadius,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: cardRadius,
                        bottomRight: cardRadius,
                      ),
                      child: AnimatedSize(
                        duration: AppAnimations.standard,
                        curve: AppAnimations.spring,
                        child: hasRunners
                            ? ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: raceRunners.length,
                                itemBuilder: (context, j) {
                                  final raceRunner = raceRunners[j];
                                  return RunnerListItem(
                                    key: ValueKey(raceRunner.runner.bibNumber),
                                    runner: raceRunner.runner,
                                    team: team,
                                    controller: widget.controller,
                                    onAction: (action) =>
                                        widget.controller.handleRaceRunnerAction(
                                      context,
                                      action,
                                      raceRunner,
                                    ),
                                    isViewMode: widget.controller.isViewMode,
                                  );
                                },
                              )
                            : _EmptyTeamState(
                                isViewMode: widget.controller.isViewMode,
                              ),
                      ),
                    ),
                  )
                : AnimatedSize(
                    duration: AppAnimations.standard,
                    curve: AppAnimations.spring,
                    child: const SizedBox.shrink(),
                  ),
          ),
        ),
      );
    }

    slivers.add(
      const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.sm)),
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: slivers,
    );
  }
}

class _TeamSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TeamSectionHeaderDelegate({
    required this.team,
    required this.runnerCount,
    required this.controller,
    required this.isExpanded,
    required this.showTitles,
    required this.headerIsFullCard,
    required this.borderColor,
    required this.cardRadius,
    required this.onToggleExpand,
    required this.onAddRunner,
    required this.isViewMode,
  });

  final Team team;
  final int runnerCount;
  final RunnersManagementController controller;
  final bool isExpanded;
  final bool showTitles;
  final bool headerIsFullCard;
  final Color borderColor;
  final Radius cardRadius;
  final VoidCallback onToggleExpand;
  final VoidCallback onAddRunner;
  final bool isViewMode;

  @override
  double get minExtent => maxExtent;

  @override
  double get maxExtent =>
      showTitles ? _kHeaderExtent + _kTitlesExtent : _kHeaderExtent;

  @override
  bool shouldRebuild(_TeamSectionHeaderDelegate old) =>
      old.team != team ||
      old.runnerCount != runnerCount ||
      old.isExpanded != isExpanded ||
      old.showTitles != showTitles ||
      old.headerIsFullCard != headerIsFullCard ||
      old.isViewMode != isViewMode;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final borderRadius = headerIsFullCard
        ? BorderRadius.circular(AppBorderRadius.md)
        : BorderRadius.only(topLeft: cardRadius, topRight: cardRadius);

    final border = headerIsFullCard
        ? Border.all(color: borderColor)
        : Border(
            top: BorderSide(color: borderColor),
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          border: border,
          borderRadius: borderRadius,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _kHeaderExtent,
                child: TeamHeaderTile(
                  team: team,
                  runnerCount: runnerCount,
                  controller: controller,
                  isExpanded: isExpanded,
                  onToggleExpand: onToggleExpand,
                  onAddRunner: onAddRunner,
                  isViewMode: isViewMode,
                ),
              ),
              if (showTitles)
                SizedBox(height: _kTitlesExtent, child: const ListTitles()),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTeamState extends StatelessWidget {
  const _EmptyTeamState({required this.isViewMode});

  final bool isViewMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        isViewMode
            ? 'No runners on this team'
            : 'No runners — tap "+ Runner" to add',
        style: AppTypography.caption.copyWith(
          color: AppColors.mediumColor,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final RunnersManagementController controller;

  @override
  Widget build(BuildContext context) {
    final hasSearch = controller.searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 48,
            color: AppColors.mediumColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            hasSearch
                ? 'No teams or runners found'
                : 'No Teams or Runners Added',
            style: AppTypography.titleSemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          if (hasSearch) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try adjusting your search',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
