import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../model/bib_conflict.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../utils/ordinal.dart';
import './inline_context_panel.dart';
import './create_runner_sheet.dart';
import './nearby_finishers_sheet.dart';
import './runner_assignment_list.dart';
import './suggested_runners.dart';
part 'duplicate_conflict_card_step1.dart';
part 'duplicate_conflict_card_multi.dart';

/// A bib recorded at more than one finish. First the coach says which finish
/// belongs to the runner whose bib it is; then, one at a time, who each of
/// the other finishes was.
class DuplicateStep1Card extends StatelessWidget {
  const DuplicateStep1Card({super.key, required this.conflict});

  final DuplicateBibConflict conflict;

  @override
  Widget build(BuildContext context) {
    final (chosen, leftover, remaining) = context.select<
        ConflictResolutionController, (int?, ConflictOccurrence?, int)>(
      (c) => (c.chosenPlace, c.currentLeftover, c.leftoversRemaining),
    );
    if (chosen != null && leftover != null) {
      return _InlineLeftoverAssignment(
        confirmedPosition: chosen,
        leftoverOccurrence: leftover,
        leftoversRemaining: remaining,
        conflict: conflict,
      );
    }

    final isMulti = conflict.occurrences.length > 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KnownRunnerCard(conflict: conflict),
        const SizedBox(height: AppSpacing.lg),
        isMulti
            ? _MultiOccurrenceStep1(conflict: conflict)
            : _TwoOccurrenceStep1(conflict: conflict),
      ],
    );
  }
}
