import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
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
import './mock_create_runner_sheet.dart';
import './nearby_finishers_sheet.dart';
import './runner_assignment_list.dart';
part 'duplicate_conflict_card_step1.dart';
part 'duplicate_conflict_card_multi.dart';

/// Step 1: Coach picks which occurrence is the correct finish position.
/// After confirming, the known runner is implicitly placed at that position
/// and the remaining occurrences are injected as unknown conflicts.
class DuplicateStep1Card extends StatelessWidget {
  const DuplicateStep1Card({super.key, required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  Widget build(BuildContext context) {
    final isMulti = conflict.occurrences.length > 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DupBadgeRow(conflict: conflict),
        const SizedBox(height: AppSpacing.md),
        _KnownRunnerCard(conflict: conflict),
        const SizedBox(height: AppSpacing.lg),
        isMulti
            ? _MultiOccurrenceStep1(conflict: conflict)
            : _TwoOccurrenceStep1(conflict: conflict),
      ],
    );
  }
}
