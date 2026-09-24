import 'package:flutter/material.dart';

import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/ordinal.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../bib_conflict_resolution/model/bib_conflict.dart';
import 'duplicate_bib_card.dart';
import 'finish_question.dart';

/// Resolving a bib that was recorded at more than one finish, in two steps:
/// which finish belongs to the runner holding the bib, then who each of the
/// others was.
///
/// Every finish is somebody: the recorder adds one row per runner and empty
/// rows are dropped before the data is sent, so a repeated bib means a
/// mistyped one, not a finish that should not be there. That is why a leftover
/// finish is assigned rather than deleted — deleting it would lose a runner
/// the Timer still has a time for.
class DuplicateBibFlow extends StatefulWidget {
  const DuplicateBibFlow({
    super.key,
    required this.conflict,
    required this.buildAssignment,
    required this.onComplete,
  });

  final DuplicateBibConflict conflict;

  /// The assign-or-create UI for one leftover finish. Call `onAssigned` with
  /// the runner the coach picked or created for it.
  final Widget Function(
    BuildContext context,
    ConflictOccurrence leftover,
    ValueChanged<RaceRunner> onAssigned,
  ) buildAssignment;

  /// Who finished at each of the bib's places, once they all have a runner.
  /// Reported in one go rather than a place at a time: until every finish has
  /// somebody, the bib is still recorded twice and nothing has been settled.
  final ValueChanged<Map<int, RaceRunner>> onComplete;

  @override
  State<DuplicateBibFlow> createState() => _DuplicateBibFlowState();
}

class _DuplicateBibFlowState extends State<DuplicateBibFlow> {
  int? _runnersPlace;
  final Map<int, RaceRunner> _assigned = {};

  /// The bib's other finishes that still have nobody.
  List<ConflictOccurrence> get _leftovers => widget.conflict.occurrences
      .where((o) => o.place != _runnersPlace && !_assigned.containsKey(o.place))
      .toList();

  void _assign(int place, RaceRunner runner) =>
      setState(() => _assigned[place] = runner);

  @override
  Widget build(BuildContext context) {
    final runnersPlace = _runnersPlace;
    if (runnersPlace == null) {
      return DuplicateBibCard(
        conflict: widget.conflict,
        onFinishChosen: (place) => setState(() => _runnersPlace = place),
      );
    }

    if (_leftovers.isEmpty) {
      // Report once the tree has settled, so the parent can close the sheet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onComplete({
            runnersPlace: widget.conflict.runner,
            ..._assigned,
          });
        }
      });
      // Nothing animated here: the parent closes the sheet on being told, and
      // a spinner left behind would spin for as long as it took.
      return _SettledBanner(
        place: runnersPlace,
        runnerName: widget.conflict.runner.runner.name ?? 'this runner',
      );
    }

    final leftover = _leftovers.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettledBanner(
          place: runnersPlace,
          runnerName: widget.conflict.runner.runner.name ?? 'this runner',
        ),
        const SizedBox(height: AppSpacing.lg),
        FinishQuestion(
          occurrence: leftover,
          reason: 'Bib #${widget.conflict.bibNumber} was a typo here',
          note: _leftovers.length > 1
              ? '${_leftovers.length} finishes left'
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        widget.buildAssignment(
          context,
          leftover,
          (runner) => _assign(leftover.place, runner),
        ),
      ],
    );
  }
}

/// Confirms the choice just made, so the coach can see it before moving on.
class _SettledBanner extends StatelessWidget {
  const _SettledBanner({required this.place, required this.runnerName});

  final int place;
  final String runnerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusFinished.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppColors.statusFinished, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$runnerName finished ${ordinal(place)}',
              style: AppTypography.smallBodySemibold
                  .copyWith(color: AppColors.statusFinished),
            ),
          ),
        ],
      ),
    );
  }
}
