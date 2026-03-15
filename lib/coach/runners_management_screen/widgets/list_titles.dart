import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

class ListTitles extends StatelessWidget {
  const ListTitles({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.smallCaption.copyWith(
      color: AppColors.mediumColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );

    return ColoredBox(
      color: AppColors.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(child: Text('NAME', style: style)),
            SizedBox(width: 36, child: Center(child: Text('GR.', style: style))),
            SizedBox(
              width: 56,
              child: Text('BIB', textAlign: TextAlign.right, style: style),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}
