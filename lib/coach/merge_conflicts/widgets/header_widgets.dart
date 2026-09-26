import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/timing_records/timing_datum.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/enums.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import '../../bib_conflict_resolution/utils/ordinal.dart';
import '../../../core/components/how_to_decide.dart';

class ConflictHeader extends StatelessWidget {
  const ConflictHeader({
    super.key,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.offBy,
    this.removedCount = 0,
    this.enteredCount = 0,
    this.firstPlace,
    this.lastPlace,
    this.suggestion,
    this.onBestGuess,
  });
  final ConflictType type;
  final String startTime;
  final String endTime;
  final int? offBy;
  final int removedCount;
  final int enteredCount;

  /// The places the batch covers, to say where in the race it is.
  final int? firstPlace;
  final int? lastPlace;

  /// Where the app thinks the problem is, e.g. "Most likely just before 10th
  /// place, where there is a 12.3 s gap."
  final String? suggestion;

  /// Applies the suggestion, for when nobody remembers.
  final VoidCallback? onBestGuess;

  @override
  Widget build(BuildContext context) {
    final several = offBy != null && offBy! > 1;
    final where = firstPlace != null && lastPlace != null
        ? ' between ${ordinal(firstPlace!)} and ${ordinal(lastPlace!)} place'
        : '';
    final String title = type == ConflictType.extraTime
        ? '${several ? '$offBy extra times' : 'An extra time'}$where'
        : '${several ? '$offBy times are' : 'A time is'} missing$where';
    final range = TimeFormatter.isDuration(startTime) &&
            TimeFormatter.isDuration(endTime)
        ? 'Times $startTime to $endTime'
        : TimeFormatter.isDuration(endTime)
            ? 'Times up to $endTime'
            : null;
    final String description = type == ConflictType.extraTime
        ? 'The Timer has more times than runners here. Tap ✕ on the time '
            'that was not a runner; the times below move up a place.'
        : 'The Timer missed a runner here. Tap + on the runner whose time is '
            'missing; the times below move down a place, and you type the '
            'missing time into the box.';

    final accent = ColorUtils.withOpacity(AppColors.primaryColor, 0.8);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(AppColors.primaryColor, 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodySemibold.copyWith(
              color: AppColors.primaryColor,
            ),
          ),
          if (range != null)
            Text(
              range,
              style: AppTypography.caption.copyWith(color: accent),
            ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTypography.smallBodyRegular.copyWith(color: accent),
          ),
          if (suggestion != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: AppColors.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    suggestion!,
                    style: AppTypography.smallBodySemibold
                        .copyWith(color: AppColors.primaryColor),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Wraps onto two lines with large text or on a narrow phone.
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (onBestGuess != null) ...[
                OutlinedButton.icon(
                  key: const ValueKey('best_guess'),
                  onPressed: onBestGuess,
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Best Guess'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                    side: const BorderSide(color: AppColors.primaryColor),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              // What Best Guess does, and when to use it, is in here.
              HowToDecide(
                tips: type == ConflictType.extraTime
                    ? ConflictTips.extraTime
                    : ConflictTips.missingTime,
                lastResort: ConflictTips.timeLastResort,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConfirmHeader extends StatelessWidget {
  const ConfirmHeader({
    super.key,
    required this.confirmTime,
  });
  final String confirmTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(Colors.green, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(Colors.green, 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(Colors.green, 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TimeFormatter.isDuration(confirmTime)
                      ? 'Confirmed Results at $confirmTime'
                      : 'Confirmed Results',
                  style: AppTypography.bodySemibold.copyWith(
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'These runner results have been confirmed',
                  style: AppTypography.smallBodyRegular.copyWith(
                    color: ColorUtils.withOpacity(Colors.green, 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmationRecord extends StatelessWidget {
  const ConfirmationRecord(this.index, this.timeRecord, {super.key});
  final int index;
  final TimingDatum timeRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorUtils.withOpacity(Colors.green, 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorUtils.withOpacity(Colors.green, 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(Colors.green, 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Confirmed',
                style: AppTypography.bodyRegular.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.withOpacity(Colors.black, 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              timeRecord.time,
              style: AppTypography.bodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
