import 'package:flutter/material.dart';
import '../../../core/utils/grade_utils.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../controller/conflict_resolution_controller.dart';
import '../utils/runner_search.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Find Runner: the list used by both DuplicateStep2Card and UnknownBibCard
/// to say who really finished at a place.
///
/// With nothing typed it lists the free runners, nearest bib first, by team.
/// Typing searches them by name, forgiving typos, or by bib. The list ends
/// with "Create new runner" (named from what was typed) for a runner who is
/// not on the roster at all. Tapping a runner selects them, and tapping again
/// unselects.
class RunnerAssignmentList extends StatefulWidget {
  const RunnerAssignmentList({
    super.key,
    required this.targetBib,
    this.forbiddenBib,
    this.onAssign,
    this.onCreateNew,
  });

  /// The bib being resolved: the list starts with the nearest bib numbers,
  /// since a mistyped bib is usually a digit or two out.
  final String targetBib;
  final String? forbiddenBib;

  /// Optional override for the assign action. When set, called instead of
  /// [ConflictResolutionController.prepareAssign] so callers can use a
  /// different controller method (e.g. [prepareAssignForDuplicate]).
  final void Function(RaceRunner runner, String label)? onAssign;

  /// Offered at the end of the list when the runner is not on the roster,
  /// with the name typed so far ('' if none).
  final void Function(String typedName)? onCreateNew;

  @override
  State<RunnerAssignmentList> createState() => _RunnerAssignmentListState();
}

class _RunnerAssignmentListState extends State<RunnerAssignmentList> {
  final _search = TextEditingController();
  String? _activeTeam; // null = "All"
  RaceRunner? _selectedRunner;

  String get _query => _search.text.trim();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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

  bool _isSelected(RaceRunner runner) =>
      _selectedRunner?.runner.bibNumber == runner.runner.bibNumber;

  void _toggle(RaceRunner runner) => setState(
      () => _selectedRunner = _isSelected(runner) ? null : runner);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();
    final candidates = controller.runnersNearBib(widget.targetBib);
    final searching = _query.isNotEmpty;

    final items = <_ListItem>[];
    if (searching) {
      for (final runner in searchRunners<RaceRunner>(
        candidates,
        _query,
        nameOf: (r) => r.runner.name ?? '',
        bibOf: (r) => r.runner.bibNumber,
      )) {
        items.add(_RunnerRow(runner: runner));
      }
    } else {
      final grouped = _groupByTeam(_filter(candidates));
      for (final team in grouped.keys) {
        items.add(_SectionHeader(team: team, count: grouped[team]!.length));
        for (final runner in grouped[team]!) {
          items.add(_RunnerRow(runner: runner));
        }
      }
    }
    // A name typed that is not a bib number names the new runner.
    final typedName = RegExp(r'^\d+$').hasMatch(_query) ? '' : _query;
    if (widget.onCreateNew != null) items.add(_CreateRow(name: typedName));

    final noMatches = items.every((i) => i is! _RunnerRow);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('find_runner_search'),
          controller: _search,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          // Names are searched loosely already; iOS "correcting" a typed
          // name ("avry" to "Avery") changed the search under the coach,
          // and its suggestion bubble covered the first result.
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() => _selectedRunner = null),
          decoration: InputDecoration(
            hintText: 'Search by name or bib',
            prefixIcon: const Icon(Icons.search, color: AppColors.mediumColor),
            suffixIcon: searching
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, color: AppColors.mediumColor),
                    onPressed: () => setState(() {
                      _search.clear();
                      _selectedRunner = null;
                    }),
                  )
                : null,
            filled: true,
            fillColor: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
          ),
        ),
        if (!searching) ...[
          const SizedBox(height: AppSpacing.md),
          _SchoolFilterPills(
            teams: controller.teams,
            activeTeam: _activeTeam,
            onChanged: (t) => setState(() {
              _activeTeam = t;
              _selectedRunner = null;
            }),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (noMatches)
          _EmptyState(
              message: searching
                  ? 'No runner on the roster matches "$_query".'
                  : candidates.isEmpty
                      ? 'Every runner already has a finish.'
                      : 'No runners from this school.'),
        // Scrollable list, bounded so the button below stays visible.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            itemBuilder: (_, i) => switch (items[i]) {
              _SectionHeader(:final team, :final count) =>
                _TeamSection(team: team, count: count),
              _RunnerRow(:final runner) => _RunnerTile(
                  key: ValueKey(runner.runner.bibNumber),
                  runner: runner,
                  isSelected: _isSelected(runner),
                  onTap: () => _toggle(runner),
                ),
              _CreateRow(:final name) => _CreateTile(
                  name: name,
                  onTap: () => widget.onCreateNew!(name),
                ),
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Outside the scroll so it stays visible once a runner is chosen.
        AnimatedSwitcher(
          duration: AppAnimations.standard,
          child: _selectedRunner == null
              ? const SizedBox.shrink()
              : _AssignCta(
                  key: ValueKey(_selectedRunner!.runner.bibNumber),
                  runnerName: _selectedRunner!.runner.name ?? '',
                  onClear: () => setState(() => _selectedRunner = null),
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
// List item descriptors for lazy ListView.builder rendering
// ---------------------------------------------------------------------------

sealed class _ListItem {}

final class _SectionHeader extends _ListItem {
  _SectionHeader({required this.team, required this.count});
  final String team;
  final int count;
}

final class _RunnerRow extends _ListItem {
  _RunnerRow({required this.runner});
  final RaceRunner runner;
}

final class _CreateRow extends _ListItem {
  _CreateRow({required this.name});
  final String name;
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

class _RunnerTile extends StatelessWidget {
  const _RunnerTile({
    super.key,
    required this.runner,
    required this.isSelected,
    required this.onTap,
  });

  final RaceRunner runner;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grade = runner.runner.grade;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.selectedRoleColor : Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.primaryColor : AppColors.lightColor,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _BibAvatar(
                bibNumber: runner.runner.bibNumber ?? '',
                isSelected: isSelected,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(runner.runner.name ?? '',
                        style: AppTypography.smallBodySemibold),
                    Text(
                      [
                        runner.team.name ?? '',
                        if (grade != null) gradeLabel(grade),
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: AppTypography.caption
                          .copyWith(color: AppColors.mediumColor),
                    ),
                  ],
                ),
              ),
              // A clear chosen / not chosen mark; tapping again unselects.
              Icon(
                isSelected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.primaryColor
                    : AppColors.mediumColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.name, required this.onTap});

  /// What was typed, or '' for a runner not yet named.
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.primaryColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_outlined,
                color: AppColors.primaryColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                name.isEmpty
                    ? 'Not on the roster? Create a new runner'
                    : 'Create new runner "$name"',
                style: AppTypography.smallBodySemibold
                    .copyWith(color: AppColors.primaryColor),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primaryColor),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BibAvatar extends StatelessWidget {
  const _BibAvatar({required this.bibNumber, required this.isSelected});

  final String bibNumber;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    // A pill that grows with the bib, rather than a circle four digits
    // spill out of.
    return AnimatedContainer(
      duration: AppAnimations.fast,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryColor
            : AppColors.primaryColor.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      alignment: Alignment.center,
      child: Text(
        bibNumber,
        maxLines: 1,
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
  const _AssignCta({
    super.key,
    required this.runnerName,
    required this.onAssign,
    required this.onClear,
  });

  final String runnerName;
  final VoidCallback onAssign;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(onPressed: onClear, child: const Text('Clear')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: GestureDetector(
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySemibold.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
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
