import 'package:flutter/material.dart';

import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/ordinal.dart';
import '../model/bib_conflict.dart';
import 'duplicate_bib_card.dart';
import 'nearby_finishers.dart';

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
    this.onFinishChosen,
  });

  final DuplicateBibConflict conflict;

  /// The assign-or-create UI for one leftover finish.
  final Widget Function(BuildContext context, ConflictOccurrence leftover)
      buildAssignment;

  /// The place the coach said belongs to the runner holding the bib.
  final ValueChanged<int>? onFinishChosen;

  @override
  State<DuplicateBibFlow> createState() => _DuplicateBibFlowState();
}

class _DuplicateBibFlowState extends State<DuplicateBibFlow> {
  int? _runnersPlace;

  List<ConflictOccurrence> get _leftovers => widget.conflict.occurrences
      .where((o) => o.place != _runnersPlace)
      .toList();

  @override
  Widget build(BuildContext context) {
    final runnersPlace = _runnersPlace;
    if (runnersPlace == null) {
      return DuplicateBibCard(
        conflict: widget.conflict,
        onFinishChosen: (place) {
          setState(() => _runnersPlace = place);
          widget.onFinishChosen?.call(place);
        },
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
        _LeftoverQuestion(
          leftover: leftover,
          bibNumber: widget.conflict.bibNumber,
          remaining: _leftovers.length,
        ),
        const SizedBox(height: AppSpacing.md),
        widget.buildAssignment(context, leftover),
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

/// The question for one leftover finish.
class _LeftoverQuestion extends StatelessWidget {
  const _LeftoverQuestion({
    required this.leftover,
    required this.bibNumber,
    required this.remaining,
  });

  final ConflictOccurrence leftover;
  final String bibNumber;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who finished ${ordinal(leftover.place)}?',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            ?leftover.time,
            'Bib #$bibNumber was a typo here',
            if (remaining > 1) '$remaining finishes left',
          ].join(' · '),
          style:
              AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        NearbyFinishersPanel(nearby: leftover.nearby),
      ],
    );
  }
}
