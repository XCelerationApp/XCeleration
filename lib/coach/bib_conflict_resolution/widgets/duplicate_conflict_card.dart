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
import './inline_context_panel.dart';
import './mock_create_runner_sheet.dart';
import './runner_assignment_list.dart';

part 'duplicate_conflict_card_step1.dart';
part 'duplicate_conflict_card_multi.dart';

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

void _showNearbySheet(
  BuildContext context,
  List<MockFinishEntry> entries,
  int conflictPosition,
  int conflictBib,
  String conflictTime,
) {
  sheet(
    context: context,
    title: 'Nearby Finishers',
    body: _NearbyFinishersSheet(
      entries: entries,
      conflictPosition: conflictPosition,
      conflictBib: conflictBib,
      conflictTime: conflictTime,
    ),
  );
}

/// Step 1: Coach picks which occurrence is the correct finish position.
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

/// Step 2: Assign a runner to the confirmed correct finish position.
class DuplicateStep2Card extends StatefulWidget {
  const DuplicateStep2Card({
    super.key,
    required this.conflict,
    required this.correctOccurrence,
  });

  final MockDuplicateConflict conflict;

  /// The confirmed finish position (e.g. 8 for 8th place).
  final int correctOccurrence;

  @override
  State<DuplicateStep2Card> createState() => _DuplicateStep2CardState();
}

class _DuplicateStep2CardState extends State<DuplicateStep2Card> {
  bool _assignMode = false;

  ({int position, String formattedTime}) get _correctEntry =>
      widget.conflict.occurrences
          .firstWhere((o) => o.position == widget.correctOccurrence);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();
    final entry = _correctEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConfirmationBanner(position: entry.position),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Who finished ${_ordinal(entry.position)}?',
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${entry.formattedTime} · Bib #${widget.conflict.bibNumber}',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        InlineContextPanel(
          surroundingFinishers: widget.conflict.surroundingFinishers,
          contextPosition: entry.position,
        ),
        TextButton(
          onPressed: () => _showNearbySheet(
            context,
            widget.conflict.surroundingFinishers,
            entry.position,
            widget.conflict.bibNumber,
            entry.formattedTime,
          ),
          child: const Text('See nearby finishers ↓'),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSize(
          duration: AppAnimations.standard,
          curve: AppAnimations.spring,
          child: _assignMode
              ? _AssignModePanel(
                  targetBib: widget.conflict.bibNumber,
                  onDismiss: () => setState(() => _assignMode = false),
                )
              : _Step2ActionButtons(
                  onAssign: () => setState(() => _assignMode = true),
                  onCreate: () => _openCreateSheet(context, controller, entry),
                ),
        ),
      ],
    );
  }

  Future<void> _openCreateSheet(
    BuildContext context,
    ConflictResolutionController controller,
    ({int position, String formattedTime}) entry,
  ) async {
    await sheet(
      context: context,
      title: 'Add New Runner',
      body: MockCreateRunnerSheet(
        allKnownBibs: controller.allKnownBibs,
        forbiddenBib: widget.conflict.bibNumber,
        onCreated: (name, bib, team, grade) {
          controller.prepareCreate(
            name,
            bib,
            team,
            grade,
            '${_ordinal(entry.position)} place',
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 sub-widgets
// ---------------------------------------------------------------------------

class _ConfirmationBanner extends StatelessWidget {
  const _ConfirmationBanner({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusFinished.withValues(alpha: AppOpacity.faint),
        border: Border.all(
          color: AppColors.statusFinished.withValues(alpha: AppOpacity.medium),
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.statusFinished, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${_ordinal(position)} place is correct',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.statusFinished,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignModePanel extends StatelessWidget {
  const _AssignModePanel({
    required this.targetBib,
    required this.onDismiss,
  });

  final int targetBib;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Assign Existing Runner', style: AppTypography.smallBodySemibold),
            const Spacer(),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 20, color: AppColors.mediumColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        RunnerAssignmentList(targetBib: targetBib),
      ],
    );
  }
}

class _Step2ActionButtons extends StatelessWidget {
  const _Step2ActionButtons({required this.onAssign, required this.onCreate});

  final VoidCallback onAssign;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SecondaryButton(
          text: 'Assign Existing Runner',
          size: ButtonSize.fullWidth,
          onPressed: onAssign,
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          text: 'Create New Runner',
          icon: Icons.person_add_outlined,
          size: ButtonSize.fullWidth,
          onPressed: onCreate,
        ),
      ],
    );
  }
}
