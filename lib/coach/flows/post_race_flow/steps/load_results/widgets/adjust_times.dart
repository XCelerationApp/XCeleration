import 'package:flutter/material.dart';

import '../../../../../../core/app_error.dart';
import '../../../../../../core/components/adjust_times_form.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/typography.dart';
import '../../../../../../core/utils/sheet_utils.dart';

export '../../../../../../core/components/adjust_times_form.dart'
    show describeShift;

/// Offers to move every time for a Timer who pressed Start late or early, and
/// shows the move once made, with a way back.
class AdjustTimesTile extends StatelessWidget {
  const AdjustTimesTile({
    super.key,
    required this.shift,
    required this.onShift,
  });

  /// How far the times have been moved so far.
  final Duration shift;

  /// Moves every time by the given amount; returns why not, if refused.
  final AppError? Function(Duration by) onShift;

  @override
  Widget build(BuildContext context) {
    final moved = shift != Duration.zero;
    return Row(
      children: [
        Expanded(
          child: Text(
            moved
                ? 'All times moved ${describeShift(shift)}.'
                : 'Timer started late or early?',
            style: AppTypography.bodyRegular
                .copyWith(color: AppColors.mediumColor),
          ),
        ),
        TextButton(
          onPressed: moved
              ? () => onShift(-shift)
              : () => sheet(
                    context: context,
                    title: 'Adjust All Times',
                    body: AdjustTimesForm(
                      onShift: onShift,
                      explanation: 'If the Timer pressed Start after the gun, '
                          'every time is short by the same amount. Started '
                          'late adds the seconds to every time; started '
                          'early takes them off.',
                    ),
                  ),
          child: Text(moved ? 'Undo' : 'Adjust Times'),
        ),
      ],
    );
  }
}
