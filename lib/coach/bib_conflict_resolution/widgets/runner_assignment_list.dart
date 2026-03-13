import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../controller/conflict_resolution_controller.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Shared resolution list used by both DuplicateStep2Card and UnknownBibCard.
/// Shows unassigned runners with school filter pills, team-grouped rows,
/// and an expand-then-confirm interaction.
class RunnerAssignmentList extends StatefulWidget {
  const RunnerAssignmentList({
    super.key,
    required this.targetBib,
    this.forbiddenBib,
    this.onAssign,
  });

  final int targetBib;
  final int? forbiddenBib;

  /// Optional override for the assign action. When set, called instead of
  /// [ConflictResolutionController.prepareAssign] so callers can use a
  /// different controller method (e.g. [prepareAssignForDuplicate]).
  final void Function(RaceRunner runner, String label)? onAssign;

  @override
  State<RunnerAssignmentList> createState() => _RunnerAssignmentListState();
}

class _RunnerAssignmentListState extends State<RunnerAssignmentList> {
  String? _activeTeam; // null = "All"
  RaceRunner? _selectedRunner;

  List<RaceRunner> _filter(List<RaceRunner> runners) {
    if (_activeTeam == null) return runners;
    return runners.where((r) => r.team.name == _activeTeam).toList();
  }

  Map<String, List<RaceRunner>> _groupByTeam(List<RaceRunner> runners) {
    final map = <String, List<RaceRunner>>{};
    for (final r in runners) {
      map.putIfAbsent(r.team.name ?? '', () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();
    final nearbyRunners = controller.runnersNearBib(widget.targetBib);
    final teams = controller.teams;
    final filtered = _filter(nearbyRunners);
    final grouped = _groupByTeam(filtered);

    var rowIndex = 0;
    final rows = <Widget>[];
    for (final team in grouped.keys) {
      rows.add(_TeamSection(team: team, count: grouped[team]!.length));
      for (final runner in grouped[team]!) {
        final idx = rowIndex++;
        rows.add(_AnimatedRunnerRow(
          key: ValueKey(runner.runner.bibNumber),
          index: idx,
          runner: runner,
          isSelected: _selectedRunner?.runner.bibNumber == runner.runner.bibNumber,
          onSelect: () => setState(() => _selectedRunner = runner),
        ));
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SchoolFilterPills(
          teams: teams,
          activeTeam: _activeTeam,
          onChanged: (t) => setState(() {
            _activeTeam = t;
            _selectedRunner = null;
          }),
        ),
        const SizedBox(height: AppSpacing.md),
        // Scrollable runner list — bounded so the CTA below stays visible.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (nearbyRunners.isEmpty)
                  _EmptyState(message: 'No unassigned runners — create a new one.')
                else if (filtered.isEmpty)
                  const _EmptyState(message: 'No runners from this school.')
                else
                  ...rows,
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // CTA lives outside the scroll so it stays visible when a runner is selected.
        AnimatedSwitcher(
          duration: AppAnimations.standard,
          child: _selectedRunner == null
              ? const SizedBox.shrink()
              : _AssignCta(
                  key: ValueKey(_selectedRunner!.runner.bibNumber),
                  runnerName: _selectedRunner!.runner.name ?? '',
                  onAssign: () {
                    final label = 'Bib #${widget.targetBib}';
                    if (widget.onAssign != null) {
                      widget.onAssign!(_selectedRunner!, label);
                    } else {
                      controller.prepareAssign(_selectedRunner!, label);
                    }
                  },
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SchoolFilterPills extends StatelessWidget {
  const _SchoolFilterPills({
    required this.teams,
    required this.activeTeam,
    required this.onChanged,
  });

  final List<String> teams;
  final String? activeTeam;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final allOptions = <String?>[null, ...teams];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: allOptions.map((team) {
          final isActive = activeTeam == team;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: GestureDetector(
              onTap: () => onChanged(team),
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.selectedRoleColor : Colors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                  border: Border.all(
                    color: isActive ? AppColors.primaryColor : AppColors.lightColor,
                  ),
                ),
                child: Text(
                  team ?? 'All',
                  style: AppTypography.smallBodyRegular.copyWith(
                    color: isActive ? AppColors.primaryColor : AppColors.mediumColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.team, required this.count});

  final String team;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            team.toUpperCase(),
            style: AppTypography.smallCaption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '· $count',
            style: AppTypography.smallCaption.copyWith(color: AppColors.mediumColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AnimatedRunnerRow extends StatefulWidget {
  const _AnimatedRunnerRow({
    super.key,
    required this.index,
    required this.runner,
    required this.isSelected,
    required this.onSelect,
  });

  final int index;
  final RaceRunner runner;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  State<_AnimatedRunnerRow> createState() => _AnimatedRunnerRowState();
}

class _AnimatedRunnerRowState extends State<_AnimatedRunnerRow> {
  double _opacity = 0;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bibInt = int.parse(widget.runner.runner.bibNumber ?? '0');
    return AnimatedOpacity(
      opacity: _opacity,
      duration: AppAnimations.reveal,
      child: GestureDetector(
        onTap: () {
          if (_expanded && !widget.isSelected) {
            widget.onSelect();
          } else {
            setState(() => _expanded = !_expanded);
          }
        },
        child: AnimatedContainer(
          duration: AppAnimations.standard,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.selectedRoleColor : Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: widget.isSelected ? AppColors.primaryColor : AppColors.lightColor,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _BibAvatar(
                    bibNumber: bibInt,
                    isSelected: widget.isSelected,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.runner.runner.name ?? '', style: AppTypography.smallBodySemibold),
                        Text(
                          widget.runner.team.name ?? '',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.mediumColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: AppAnimations.fast,
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.mediumColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: AppAnimations.standard,
                curve: AppAnimations.spring,
                child: _expanded
                    ? _ExpandedDetail(runner: widget.runner, onSelect: widget.onSelect)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ExpandedDetail extends StatelessWidget {
  const _ExpandedDetail({required this.runner, required this.onSelect});

  final RaceRunner runner;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          _chip('Grade ${runner.runner.grade ?? '—'}'),
          const SizedBox(width: AppSpacing.xs),
          _chip('Bib #${runner.runner.bibNumber ?? '—'}'),
          const Spacer(),
          ElevatedButton(
            onPressed: onSelect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
            ),
            child: Text(
              'Select',
              style: AppTypography.smallBodySemibold.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppBorderRadius.xs),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BibAvatar extends StatelessWidget {
  const _BibAvatar({required this.bibNumber, required this.isSelected});

  final int bibNumber;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryColor
            : AppColors.primaryColor.withValues(alpha: AppOpacity.light),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '#$bibNumber',
        style: AppTypography.caption.copyWith(
          color: isSelected ? Colors.white : AppColors.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AssignCta extends StatelessWidget {
  const _AssignCta({super.key, required this.runnerName, required this.onAssign});

  final String runnerName;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAssign,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryColor, Color(0xFFFF7043)],
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        ),
        alignment: Alignment.center,
        child: Text(
          'Assign $runnerName →',
          style: AppTypography.bodySemibold.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Text(
          message,
          style: AppTypography.smallBodyRegular.copyWith(color: AppColors.mediumColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
