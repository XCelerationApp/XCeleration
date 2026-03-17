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

class RunnersList extends StatefulWidget {
  const RunnersList({super.key, required this.controller});

  final RunnersManagementController controller;

  @override
  State<RunnersList> createState() => _RunnersListState();
}

class _RunnersListState extends State<RunnersList> {
  // teamId → expanded; default true (all sections start open)
  final Map<int, bool> _expanded = {};

  bool _isExpanded(Team team) =>
      _expanded[team.teamId] ?? true;

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
      future: widget.controller.masterRace.filteredSearchResults,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          );
        }

        final teamMap = snapshot.data!;

        if (teamMap.isEmpty) {
          return _EmptyState(controller: widget.controller);
        }

        return _buildList(context, teamMap);
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    Map<Team, List<RaceRunner>> teamMap,
  ) {
    final teams = teamMap.keys.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    return AnimatedSwitcher(
      duration: AppAnimations.standard,
      child: ListView.builder(
        key: ValueKey(teams.length),
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: teams.length,
        itemBuilder: (context, index) {
          final team = teams[index];
          final raceRunners = teamMap[team] ?? [];
          final expanded = _isExpanded(team);

          return _AnimatedTeamSection(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.mediumColor.withValues(alpha: AppOpacity.faint),
                  border: Border.all(
                    color: AppColors.mediumColor.withValues(alpha: AppOpacity.medium),
                  ),
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TeamHeaderTile(
                        team: team,
                        runnerCount: raceRunners.length,
                        controller: widget.controller,
                        isExpanded: expanded,
                        onToggleExpand: () => _toggleExpanded(team),
                        onAddRunner: () =>
                            widget.controller.showAddRunnerChoiceSheet(
                          context,
                          team,
                        ),
                        isViewMode: widget.controller.isViewMode,
                      ),
                      // Collapsible runner rows with column headers
                      AnimatedSize(
                        duration: AppAnimations.standard,
                        curve: AppAnimations.spring,
                        child: expanded
                            ? Column(
                                  children: [
                                    if (raceRunners.isNotEmpty) const ListTitles(),
                                    if (raceRunners.isEmpty)
                                      _EmptyTeamState(
                                        isViewMode: widget.controller.isViewMode,
                                      )
                                    else
                                      ...raceRunners.map((raceRunner) {
                                        return RunnerListItem(
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
                                      }),
                                  ],
                                )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Staggered fade-in wrapper for each team section.
class _AnimatedTeamSection extends StatefulWidget {
  const _AnimatedTeamSection({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_AnimatedTeamSection> createState() => _AnimatedTeamSectionState();
}

class _AnimatedTeamSectionState extends State<_AnimatedTeamSection> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: widget.index * 40),
      () {
        if (mounted) setState(() => _opacity = 1);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      curve: AppAnimations.enter,
      child: widget.child,
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
