import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_shadows.dart';
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
  Future<Map<Team, List<RaceRunner>>>? _filteredFuture;

  // Sticky header state
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Map<int, GlobalKey> _sectionKeys = {};
  Map<Team, List<RaceRunner>>? _currentTeamMap;
  Team? _stickyTeam;

  // Approximate runner row height (padding + text + divider)
  static const double _runnerRowHeight = 48.0;

  // Unstick when fewer than ~4 runner rows remain below the sticky header
  static const double _releaseThreshold = _runnerRowHeight * 4;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateSticky);
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
    _scrollController.removeListener(_updateSticky);
    _scrollController.dispose();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {
      _filteredFuture = widget.controller.filteredSearchResults;
    });
  }

  bool _isExpanded(Team team) =>
      _expanded[team.teamId ?? -1] ?? true;

  void _toggleExpanded(Team team) {
    setState(() {
      _expanded[team.teamId ?? -1] = !_isExpanded(team);
    });
    // Re-evaluate sticky state after collapse/expand settles
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSticky());
  }

  void _updateSticky() {
    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || _currentTeamMap == null) return;
    final listTop = listBox.localToGlobal(Offset.zero).dy;

    // Find the section whose header has just scrolled off the top and still
    // has enough content below the sticky position. If multiple qualify
    // (unlikely), pick the one whose top is closest to 0.
    Team? newStickyTeam;
    double bestTop = double.negativeInfinity;

    for (final entry in _sectionKeys.entries) {
      final teamId = entry.key;
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final sectionTop = box.localToGlobal(Offset.zero).dy - listTop;
      final sectionBottom = sectionTop + box.size.height;

      if (sectionTop < 0 && sectionBottom > _releaseThreshold && sectionTop > bestTop) {
        bestTop = sectionTop;
        for (final team in _currentTeamMap!.keys) {
          if (team.teamId == teamId) {
            newStickyTeam = team;
            break;
          }
        }
      }
    }

    if (newStickyTeam != _stickyTeam) {
      setState(() => _stickyTeam = newStickyTeam);
    }
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
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          );
        }

        final teamMap = snapshot.requireData;

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
    _currentTeamMap = teamMap;

    final teams = teamMap.keys.toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));

    // Ensure a stable GlobalKey exists for each team section
    for (final team in teams) {
      _sectionKeys.putIfAbsent(team.teamId ?? -1, GlobalKey.new);
    }

    // Resolve the sticky team by teamId so identity changes in the map don't
    // cause a missed match after a rebuild.
    Team? resolvedStickyTeam;
    int resolvedRunnerCount = 0;
    final stickyId = _stickyTeam?.teamId;
    if (stickyId != null) {
      for (final entry in teamMap.entries) {
        if (entry.key.teamId == stickyId) {
          resolvedStickyTeam = entry.key;
          resolvedRunnerCount = entry.value.length;
          break;
        }
      }
    }

    return Stack(
      children: [
        ListView.builder(
          key: _listKey,
          controller: _scrollController,
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
                key: _sectionKeys[team.teamId ?? -1],
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
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: raceRunners.length,
                                          itemBuilder: (context, i) {
                                            final raceRunner = raceRunners[i];
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
                                        ),
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
        if (resolvedStickyTeam != null)
          _StickyTeamHeader(
            team: resolvedStickyTeam,
            runnerCount: resolvedRunnerCount,
            controller: widget.controller,
            isExpanded: _isExpanded(resolvedStickyTeam),
            onToggleExpand: () => _toggleExpanded(resolvedStickyTeam!),
            onAddRunner: () => widget.controller.showAddRunnerChoiceSheet(
              context,
              resolvedStickyTeam!,
            ),
            isViewMode: widget.controller.isViewMode,
          ),
      ],
    );
  }
}

/// Floating sticky header shown when a team section's header scrolls off-screen.
class _StickyTeamHeader extends StatelessWidget {
  const _StickyTeamHeader({
    required this.team,
    required this.runnerCount,
    required this.controller,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onAddRunner,
    required this.isViewMode,
  });

  final Team team;
  final int runnerCount;
  final RunnersManagementController controller;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onAddRunner;
  final bool isViewMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: AppShadows.low,
      ),
      child: TeamHeaderTile(
        team: team,
        runnerCount: runnerCount,
        controller: controller,
        isExpanded: isExpanded,
        onToggleExpand: onToggleExpand,
        onAddRunner: onAddRunner,
        isViewMode: isViewMode,
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

class _AnimatedTeamSectionState extends State<_AnimatedTeamSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final staggerMs = widget.index * 40;
    final totalMs = staggerMs + AppAnimations.reveal.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        staggerMs / totalMs,
        1.0,
        curve: AppAnimations.enter,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
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
