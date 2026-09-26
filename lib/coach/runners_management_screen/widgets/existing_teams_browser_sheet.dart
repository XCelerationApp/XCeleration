import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/grade_utils.dart';
import '../../../shared/models/database/runner.dart';
import '../../../shared/models/database/team.dart';

class ExistingTeamsBrowserSheet extends StatefulWidget {
  const ExistingTeamsBrowserSheet({
    super.key,
    required this.availableTeams,
    required this.raceId,
  });

  final Map<Team, List<Runner>> availableTeams;
  final int raceId;

  @override
  State<ExistingTeamsBrowserSheet> createState() =>
      _ExistingTeamsBrowserSheetState();
}

class _ExistingTeamsBrowserSheetState
    extends State<ExistingTeamsBrowserSheet> {
  final Map<int, Set<int>> _selectedRunners = {};
  late final List<Team> _teams;
  late final Map<int, List<Runner>> _teamRunners;

  /// Teams opened to show their runners. All start closed: every team the
  /// coach ever had used to be listed open, so reaching the next team meant
  /// scrolling past the whole of the last one.
  final Set<int> _expanded = {};
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _runnerMatches(Runner r) =>
      (r.name ?? '').toLowerCase().contains(_query) ||
      (r.bibNumber ?? '').contains(_query);

  /// The teams to list, and for each the runners to show: every team and
  /// runner without a search; with one, teams whose name matches (with all
  /// their runners) or that have a matching runner (with just those).
  List<(Team, List<Runner>)> get _visible => [
        for (final team in _teams)
          if (_query.isEmpty ||
              (team.name ?? '').toLowerCase().contains(_query))
            (team, _teamRunners[team.teamId!] ?? const [])
          else if ((_teamRunners[team.teamId!] ?? const [])
              .any(_runnerMatches))
            (team, _teamRunners[team.teamId!]!.where(_runnerMatches).toList()),
      ];

  @override
  void initState() {
    super.initState();
    _teams = widget.availableTeams.keys.toList();
    _teamRunners = {};
    for (final team in _teams) {
      final id = team.teamId!;
      _teamRunners[id] = widget.availableTeams[team] ?? [];
      _selectedRunners[id] = <int>{};
    }
  }

  // --- selection helpers ---

  _SelectionState _teamSelectionState(int teamId) {
    final runners = _teamRunners[teamId] ?? [];
    final selected = _selectedRunners[teamId] ?? {};
    if (runners.isEmpty) {
      return selected.isEmpty ? _SelectionState.none : _SelectionState.all;
    }
    final validIds = runners
        .where((r) => r.runnerId != null)
        .map((r) => r.runnerId!)
        .toSet();
    if (selected.isEmpty) return _SelectionState.none;
    if (selected.containsAll(validIds)) return _SelectionState.all;
    return _SelectionState.partial;
  }

  void _toggleTeam(int teamId) {
    setState(() {
      final state = _teamSelectionState(teamId);
      if (state == _SelectionState.all) {
        _selectedRunners[teamId]!.clear();
      } else {
        _selectedRunners[teamId] = _teamRunners[teamId]!
            .where((r) => r.runnerId != null)
            .map((r) => r.runnerId!)
            .toSet();
      }
    });
  }

  void _toggleRunner(int teamId, int runnerId) {
    setState(() {
      if (_selectedRunners[teamId]!.contains(runnerId)) {
        _selectedRunners[teamId]!.remove(runnerId);
      } else {
        _selectedRunners[teamId]!.add(runnerId);
      }
    });
  }

  int get _totalSelectedRunners =>
      _selectedRunners.values.fold(0, (sum, s) => sum + s.length);

  Map<Team, List<Runner>> _buildResult() {
    final result = <Team, List<Runner>>{};
    for (final team in _teams) {
      final id = team.teamId!;
      final selected = _selectedRunners[id] ?? {};
      if (selected.isEmpty) continue;
      result[team] = _teamRunners[id]!
          .where((r) => r.runnerId != null && selected.contains(r.runnerId))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_teams.isEmpty) {
      return Center(
        child: Text(
          'No teams from other races to import.',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final visible = _visible;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('import_team_search'),
          controller: _search,
          autocorrect: false,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search teams, runners or bibs',
            prefixIcon: const Icon(Icons.search, color: AppColors.mediumColor),
            filled: true,
            fillColor: AppColors.surfaceColor,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'No team or runner matches "${_search.text.trim()}".',
              style: AppTypography.bodyRegular
                  .copyWith(color: AppColors.mediumColor),
              textAlign: TextAlign.center,
            ),
          ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final (team, runners) = visible[index];
              final teamId = team.teamId!;
              final selState = _teamSelectionState(teamId);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _TeamCard(
                  team: team,
                  runners: runners,
                  runnerCount: _teamRunners[teamId]?.length ?? 0,
                  // A search for a runner opens their team to show them.
                  expanded: _expanded.contains(teamId) ||
                      (_query.isNotEmpty &&
                          !(team.name ?? '').toLowerCase().contains(_query)),
                  onToggleExpanded: () => setState(() {
                    if (!_expanded.remove(teamId)) _expanded.add(teamId);
                  }),
                  selectionState: selState,
                  selectedRunnerIds: _selectedRunners[teamId] ?? {},
                  onToggleTeam: () => _toggleTeam(teamId),
                  onToggleRunner: (rid) => _toggleRunner(teamId, rid),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _ImportButton(
          runnerCount: _totalSelectedRunners,
          onPressed: _totalSelectedRunners > 0
              ? () => Navigator.of(context).pop(_buildResult())
              : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Selection state enum
// ---------------------------------------------------------------------------

enum _SelectionState { none, partial, all }

// ---------------------------------------------------------------------------
// Team card
// ---------------------------------------------------------------------------

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.runners,
    required this.runnerCount,
    required this.expanded,
    required this.onToggleExpanded,
    required this.selectionState,
    required this.selectedRunnerIds,
    required this.onToggleTeam,
    required this.onToggleRunner,
  });

  final Team team;

  /// The runners shown, which a search can narrow.
  final List<Runner> runners;

  /// How many runners the whole team has.
  final int runnerCount;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final _SelectionState selectionState;
  final Set<int> selectedRunnerIds;
  final VoidCallback onToggleTeam;
  final ValueChanged<int> onToggleRunner;

  @override
  Widget build(BuildContext context) {
    final teamColor = team.color ?? AppColors.primaryColor;
    final isNone = selectionState == _SelectionState.none;

    return AnimatedContainer(
      duration: AppAnimations.standard,
      curve: AppAnimations.spring,
      decoration: BoxDecoration(
        color: isNone
            ? AppColors.backgroundColor
            : teamColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(
          color: isNone
              ? AppColors.lightColor
              : teamColor.withValues(alpha: AppOpacity.medium),
          width: isNone ? 1 : 1.5,
        ),
      ),
      child: Column(
        children: [
          // Team header row
          _TeamHeader(
            team: team,
            runnerCount: runnerCount,
            expanded: expanded,
            selectionState: selectionState,
            onToggle: onToggleTeam,
            onToggleExpanded: onToggleExpanded,
          ),
          // Runner rows
          if (expanded && runners.isNotEmpty) ...[
            Divider(height: 1, thickness: 1, color: AppColors.lightColor),
            ...runners.map((runner) {
              final rid = runner.runnerId!;
              final isSelected = selectedRunnerIds.contains(rid);
              return _RunnerRow(
                runner: runner,
                teamColor: teamColor,
                isSelected: isSelected,
                onToggle: () => onToggleRunner(rid),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({
    required this.team,
    required this.runnerCount,
    required this.expanded,
    required this.selectionState,
    required this.onToggle,
    required this.onToggleExpanded,
  });

  final Team team;
  final int runnerCount;
  final bool expanded;
  final _SelectionState selectionState;

  /// Picks or clears the whole team, from its checkbox.
  final VoidCallback onToggle;

  /// Opens or closes the team's runners, from the rest of the row.
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final teamColor = team.color ?? AppColors.primaryColor;

    return InkWell(
      onTap: onToggleExpanded,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppBorderRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: Row(
          children: [
            // Its own, larger tap target, so picking the whole team doesn't
            // open it and opening it doesn't pick it.
            InkWell(
              key: ValueKey('import_team_${team.teamId}'),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _TeamCheckbox(state: selectionState, color: teamColor),
              ),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius:
                    BorderRadius.circular(AppBorderRadius.full),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                team.name ?? '',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: teamColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$runnerCount runner${runnerCount == 1 ? '' : 's'}',
              style: AppTypography.smallCaption.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: AppColors.mediumColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Three-state checkbox
class _TeamCheckbox extends StatelessWidget {
  const _TeamCheckbox({required this.state, required this.color});

  final _SelectionState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final checked = state == _SelectionState.all;
    final partial = state == _SelectionState.partial;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked || partial
            ? color
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.xs),
        border: Border.all(
          color: checked || partial ? color : AppColors.mediumColor,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(Icons.check, size: 14, color: AppColors.backgroundColor)
          : partial
              ? Icon(Icons.remove, size: 14, color: AppColors.backgroundColor)
              : null,
    );
  }
}

class _RunnerRow extends StatelessWidget {
  const _RunnerRow({
    required this.runner,
    required this.teamColor,
    required this.isSelected,
    required this.onToggle,
  });

  final Runner runner;
  final Color teamColor;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              activeColor: teamColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                runner.name ?? '-',
                style: AppTypography.smallBodyRegular.copyWith(
                  color: AppColors.darkColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 32,
              child: Center(
                child: Text(
                  gradeLabel(runner.grade),
                  style: AppTypography.smallCaption.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Center(
                child: Text(
                  runner.bibNumber ?? '-',
                  style: AppTypography.smallCaption.copyWith(
                    color: teamColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.runnerCount, this.onPressed});

  final int runnerCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = runnerCount > 0
        ? 'Import $runnerCount Runner${runnerCount == 1 ? '' : 's'}'
        : 'Select runners to import';

    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          disabledBackgroundColor:
              AppColors.primaryColor.withValues(alpha: AppOpacity.solid),
          foregroundColor: AppColors.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTypography.bodySemibold.copyWith(
            color: onPressed != null
                ? AppColors.backgroundColor
                : AppColors.backgroundColor.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
