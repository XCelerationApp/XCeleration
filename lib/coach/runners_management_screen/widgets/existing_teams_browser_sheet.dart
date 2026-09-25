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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: _teams.length,
            itemBuilder: (context, index) {
              final team = _teams[index];
              final teamId = team.teamId!;
              final runners = _teamRunners[teamId] ?? [];
              final selState = _teamSelectionState(teamId);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _TeamCard(
                  team: team,
                  runners: runners,
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
    required this.selectionState,
    required this.selectedRunnerIds,
    required this.onToggleTeam,
    required this.onToggleRunner,
  });

  final Team team;
  final List<Runner> runners;
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
            runners: runners,
            selectionState: selectionState,
            onToggle: onToggleTeam,
          ),
          // Runner rows
          if (runners.isNotEmpty) ...[
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
    required this.runners,
    required this.selectionState,
    required this.onToggle,
  });

  final Team team;
  final List<Runner> runners;
  final _SelectionState selectionState;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final teamColor = team.color ?? AppColors.primaryColor;
    final runnerCount = runners.length;

    return InkWell(
      onTap: onToggle,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppBorderRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _TeamCheckbox(state: selectionState, color: teamColor),
            const SizedBox(width: AppSpacing.sm),
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
