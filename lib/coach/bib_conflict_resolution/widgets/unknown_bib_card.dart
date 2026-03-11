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

/// Card for a standalone unknown bib — bib was entered but not found in the database.
/// v2 layout: header with badge + finish position, time pill, inline context panel,
/// and two action buttons that expand into assign mode or open the create sheet.
class UnknownBibCard extends StatefulWidget {
  const UnknownBibCard({super.key, required this.conflict});

  final MockUnknownConflict conflict;

  @override
  State<UnknownBibCard> createState() => _UnknownBibCardState();
}

class _UnknownBibCardState extends State<UnknownBibCard> {
  bool _assignMode = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderRow(conflict: widget.conflict),
        const SizedBox(height: AppSpacing.md),
        _TimePill(formattedTime: widget.conflict.formattedTime),
        const SizedBox(height: AppSpacing.md),
        InlineContextPanel(
          surroundingFinishers: widget.conflict.surroundingFinishers,
          contextPosition: widget.conflict.position,
        ),
        TextButton(
          onPressed: () => _openContextSheet(context),
          child: const Text('See more nearby finishers ↓'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: AppAnimations.standard,
          curve: AppAnimations.spring,
          child: _assignMode
              ? _AssignModePanel(
                  targetBib: widget.conflict.enteredBib,
                  onDismiss: () => setState(() => _assignMode = false),
                )
              : _ActionButtons(
                  onAssign: () => setState(() => _assignMode = true),
                  onCreate: () => _openCreateSheet(context, controller),
                ),
        ),
      ],
    );
  }

  void _openContextSheet(BuildContext context) {
    sheet(
      context: context,
      title: 'Nearby Finishers',
      body: _NearbyFinishersSheet(
        entries: widget.conflict.surroundingFinishers,
        conflictPosition: widget.conflict.position,
        conflictBib: widget.conflict.enteredBib,
        conflictTime: widget.conflict.formattedTime,
      ),
    );
  }

  Future<void> _openCreateSheet(
    BuildContext context,
    ConflictResolutionController controller,
  ) async {
    // TODO(xce-181): pass autoBib: conflict.enteredBib once XCE-181 adds that parameter.
    await sheet(
      context: context,
      title: 'Add New Runner',
      body: MockCreateRunnerSheet(
        allKnownBibs: controller.allKnownBibs,
        onCreated: (name, bib, team, grade) {
          controller.prepareCreate(
            name,
            bib,
            team,
            grade,
            'Bib #${widget.conflict.enteredBib}',
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.conflict});

  final MockUnknownConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.redColor.withValues(alpha: AppOpacity.light),
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          ),
          child: const Icon(
            Icons.help_outline,
            color: AppColors.redColor,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNKNOWN BIB',
              style: AppTypography.extraSmall.copyWith(
                letterSpacing: 0.5,
                color: AppColors.redColor,
              ),
            ),
            Text(
              '#${conflict.enteredBib}',
              style: AppTypography.titleSemibold.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Finished',
              style: AppTypography.extraSmall.copyWith(
                letterSpacing: 0.5,
                color: AppColors.mediumColor,
              ),
            ),
            Text(
              _ordinal(conflict.position),
              style: AppTypography.titleSemibold.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.formattedTime});

  final String formattedTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightColor.withValues(alpha: AppOpacity.solid),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 14,
            color: AppColors.mediumColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            formattedTime,
            style: AppTypography.bodySemibold.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
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
            Text(
              'Assign Existing Runner',
              style: AppTypography.smallBodySemibold,
            ),
            const Spacer(),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(
                Icons.close,
                size: 20,
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        RunnerAssignmentList(targetBib: targetBib),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onAssign, required this.onCreate});

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

class _NearbyFinishersSheet extends StatelessWidget {
  const _NearbyFinishersSheet({
    required this.entries,
    required this.conflictPosition,
    required this.conflictBib,
    required this.conflictTime,
  });

  final List<MockFinishEntry> entries;
  final int conflictPosition;
  final int conflictBib;
  final String conflictTime;

  @override
  Widget build(BuildContext context) {
    final allRows = <(int, Widget)>[
      for (final e in entries) (e.position, _FinisherRow(entry: e)),
      (
        conflictPosition,
        _ConflictFinisherRow(
          position: conflictPosition,
          bib: conflictBib,
          time: conflictTime,
        ),
      ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: allRows.map((r) => r.$2).toList(),
    );
  }
}

class _FinisherRow extends StatelessWidget {
  const _FinisherRow({required this.entry});

  final MockFinishEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _ordinal(entry.position),
              style: AppTypography.caption.copyWith(
                color: AppColors.mediumColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.runnerName,
              style: AppTypography.smallBodyRegular,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            entry.formattedTime,
            style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
          ),
        ],
      ),
    );
  }
}

class _ConflictFinisherRow extends StatelessWidget {
  const _ConflictFinisherRow({
    required this.position,
    required this.bib,
    required this.time,
  });

  final int position;
  final int bib;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: const Border(
          left: BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _ordinal(position),
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Bib #$bib',
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            time,
            style: AppTypography.caption.copyWith(color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }
}
