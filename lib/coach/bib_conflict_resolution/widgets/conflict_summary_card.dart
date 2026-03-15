import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/conflict_resolution_controller.dart';
import '../mock/conflict_mock_data.dart';
import '../../../core/components/button_components.dart';
import '../../../core/components/race_components.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Entry screen: summarises the conflict counts and lets the recorder start.
class ConflictSummaryCard extends StatelessWidget {
  const ConflictSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ConflictResolutionController>();

    final duplicateCount = ConflictMockData.conflicts
        .whereType<MockDuplicateConflict>()
        .length;
    final unknownCount = ConflictMockData.conflicts
        .whereType<MockUnknownConflict>()
        .length;

    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),
            _Header(
              duplicateCount: duplicateCount,
              unknownCount: unknownCount,
            ),
            const SizedBox(height: AppSpacing.xl),
            _ConflictTypeCards(
              duplicateCount: duplicateCount,
              unknownCount: unknownCount,
            ),
            const SizedBox(height: AppSpacing.xxl),
            FullWidthButton(
              text: 'Start Resolving',
              onPressed: controller.startResolving,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.duplicateCount, required this.unknownCount});

  final int duplicateCount;
  final int unknownCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolve Bib Conflicts', style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$duplicateCount duplicate ${duplicateCount == 1 ? 'bib' : 'bibs'} · '
          '$unknownCount unknown ${unknownCount == 1 ? 'bib' : 'bibs'}',
          style: AppTypography.bodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Every finish place must be assigned a real, identified runner '
          'before results can be submitted.',
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.mediumColor,
          ),
        ),
      ],
    );
  }
}

class _ConflictTypeCards extends StatelessWidget {
  const _ConflictTypeCards({
    required this.duplicateCount,
    required this.unknownCount,
  });

  final int duplicateCount;
  final int unknownCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ConflictButton(
          title: 'Duplicate Bibs',
          subtitle: '$duplicateCount bib${duplicateCount == 1 ? '' : 's'} recorded at two finish places. '
              'You\'ll pick which is correct, then fix the other.',
          icon: Icons.copy_outlined,
          color: Colors.orange,
          onPressed: () {},
          isEnabled: false,
        ),
        ConflictButton(
          title: 'Unknown Bibs',
          subtitle: '$unknownCount bib${unknownCount == 1 ? '' : 's'} not found in the database. '
              'Assign to an existing runner or create a new one.',
          icon: Icons.help_outline,
          color: AppColors.primaryColor,
          onPressed: () {},
          isEnabled: false,
        ),
      ],
    );
  }
}
