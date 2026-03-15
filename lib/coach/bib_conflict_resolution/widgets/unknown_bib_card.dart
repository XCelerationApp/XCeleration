import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../utils/ordinal.dart';
import './inline_context_panel.dart';
import './nearby_finishers_sheet.dart';
import './mock_create_runner_sheet.dart';
import './runner_assignment_list.dart';

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
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderCard(conflict: widget.conflict),
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
        _ActionButtons(
          onAssign: () => _openAssignSheet(context),
          onCreate: () => _openCreateSheet(context),
        ),
      ],
    );
  }

  void _openContextSheet(BuildContext context) {
    showNearbySheet(
      context,
      entries: widget.conflict.surroundingFinishers,
      conflictPosition: widget.conflict.position,
      conflictBib: widget.conflict.enteredBib,
      conflictTime: widget.conflict.formattedTime,
    );
  }

  Future<void> _openAssignSheet(BuildContext context) async {
    final controller = context.read<ConflictResolutionController>();
    RaceRunner? pendingRunner;
    String? pendingLabel;

    await sheet(
      context: context,
      title: 'Assign Existing Runner',
      body: ChangeNotifierProvider.value(
        value: controller,
        child: RunnerAssignmentList(
          targetBib: widget.conflict.enteredBib,
          onAssign: (runner, label) {
            pendingRunner = runner;
            pendingLabel = label;
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    if (pendingRunner != null) {
      controller.prepareAssign(pendingRunner!, pendingLabel!);
    }
  }

  Future<void> _openCreateSheet(BuildContext context) async {
    final controller = context.read<ConflictResolutionController>();
    await sheet(
      context: context,
      title: 'Add New Runner',
      body: MockCreateRunnerSheet(
        allKnownBibs: controller.allKnownBibs,
        teams: controller.teams,
        autoBib: widget.conflict.enteredBib,
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

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.conflict});

  final MockUnknownConflict conflict;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.redColor.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.redColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                    ordinal(conflict.position),
                    style: AppTypography.titleSemibold.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 14,
                color: AppColors.mediumColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                conflict.formattedTime,
                style: AppTypography.bodySemibold.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
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

