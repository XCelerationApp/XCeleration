import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import './runner_assignment_list.dart';

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1: return '${n}st';
    case 2: return '${n}nd';
    case 3: return '${n}rd';
    default: return '${n}th';
  }
}

/// Step 1: Shows both duplicate occurrences side by side.
/// The recorder picks which finish position actually had this bib.
class DuplicateStep1Card extends StatelessWidget {
  const DuplicateStep1Card({super.key, required this.conflict});

  final MockDuplicateConflict conflict;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ConflictResolutionController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duplicate Bib', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          conflict.runnerName,
          style: AppTypography.titleSemibold,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${conflict.team} · Grade ${conflict.grade}',
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Bib #${conflict.bibNumber} was recorded at two finish places. '
          'Which one is correct?',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OccurrenceTile(
                label: _ordinal(conflict.entry1.position),
                time: conflict.entry1.formattedTime,
                onCorrect: () => controller.chooseDuplicateOccurrence(1),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _OccurrenceTile(
                label: _ordinal(conflict.entry2.position),
                time: conflict.entry2.formattedTime,
                onCorrect: () => controller.chooseDuplicateOccurrence(2),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OccurrenceTile extends StatefulWidget {
  const _OccurrenceTile({
    required this.label,
    required this.time,
    required this.onCorrect,
  });

  final String label;
  final String time;
  final VoidCallback onCorrect;

  @override
  State<_OccurrenceTile> createState() => _OccurrenceTileState();
}

class _OccurrenceTileState extends State<_OccurrenceTile> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.standard,
      curve: AppAnimations.spring,
      decoration: BoxDecoration(
        color: _confirmed
            ? AppColors.primaryColor.withValues(alpha: 0.08)
            : Colors.white,
        border: Border.all(
          color: _confirmed ? AppColors.primaryColor : AppColors.lightColor,
          width: _confirmed ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(widget.label, style: AppTypography.titleSemibold),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.time,
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_confirmed)
            Icon(Icons.check_circle, color: AppColors.primaryColor, size: 28)
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _confirmed = true);
                  Future.delayed(AppAnimations.standard, widget.onCorrect);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
                child: Text('This one', style: AppTypography.smallBodySemibold),
              ),
            ),
        ],
      ),
    );
  }
}

/// Step 2 (inline): The "wrong" entry now needs a real runner assigned.
class DuplicateStep2Card extends StatelessWidget {
  const DuplicateStep2Card({
    super.key,
    required this.conflict,
    required this.correctOccurrence,
  });

  final MockDuplicateConflict conflict;

  /// 1 = entry1 was correct (entry2 needs fixing), 2 = entry2 was correct.
  final int correctOccurrence;

  @override
  Widget build(BuildContext context) {
    final wrongEntry =
        correctOccurrence == 1 ? conflict.entry2 : conflict.entry1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fix the other entry', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_ordinal(wrongEntry.position)} place (${wrongEntry.formattedTime}) '
          'needs a different runner — Bib #${conflict.bibNumber} is already taken.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.xl),
        RunnerAssignmentList(
          targetBib: conflict.bibNumber,
          forbiddenBib: conflict.bibNumber,
        ),
      ],
    );
  }
}
