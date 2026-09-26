import 'package:flutter/material.dart';
import 'package:xceleration/coach/flows/model/flow_model.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/time_formatter.dart';
import 'package:xceleration/shared/models/database/race_result.dart';

import '../load_results/controller/load_results_controller.dart';

/// The last page of collecting results: the finish order and times as they
/// will be saved, for the coach to look over before saving. Back returns to
/// Load Results to load them again.
class ReviewResultsStep extends FlowStep {
  ReviewResultsStep({required this.controller})
      : super(
          title: 'Check the Results',
          // Loading again throws away every correction made so far, so the
          // way to fix one result is Edit, once saved.
          description: 'This is the finish order and times that will be '
              'saved. If one result is wrong, save anyway and tap Edit on '
              'the Results tab to fix it.',
          content: const SizedBox.shrink(),
          canScroll: false,
          nextLabel: 'Save Results',
          onNext: () async {
            // A failed save must keep the flow here: finishing would mark the
            // race done without results.
            final error = await controller.saveCurrentResults();
            if (error != null) throw FlowStepBlocked(error.userMessage);
          },
        ) {
    controller.addListener(notifyContentChanged);
  }

  final LoadResultsController controller;

  late final Widget _content = ReviewResultsList(controller: controller);

  @override
  Widget get content => _content;

  @override
  bool Function()? get canProceed =>
      () => controller.buildResults().error == null;

  @override
  String? Function()? get blockedReason =>
      () => controller.buildResults().error?.userMessage;

  @override
  void dispose() {
    controller.removeListener(notifyContentChanged);
    super.dispose();
  }
}

/// Each finisher in order: place, name, team, bib and time.
class ReviewResultsList extends StatelessWidget {
  const ReviewResultsList({super.key, required this.controller});

  final LoadResultsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final built = controller.buildResults();
        if (built.error case final error?) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              error.userMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyRegular
                  .copyWith(color: AppColors.redColor),
            ),
          );
        }
        final results = built.results;
        final teams = {for (final r in results) r.team?.name}.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                '${results.length} finishers from $teams '
                '${teams == 1 ? 'team' : 'teams'}',
                style: AppTypography.bodySemibold
                    .copyWith(color: AppColors.mediumColor),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                itemCount: results.length,
                itemBuilder: (context, i) =>
                    _FinisherRow(result: results[i], shaded: i.isOdd),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FinisherRow extends StatelessWidget {
  const _FinisherRow({required this.result, required this.shaded});

  final RaceResult result;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final runner = result.runner;
    final team = result.team?.abbreviation ?? result.team?.name ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: shaded ? AppColors.surfaceColor : Colors.transparent,
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('${result.place}', style: AppTypography.bodySemibold),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(runner?.name ?? '',
                    style: AppTypography.bodyRegular,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$team · Bib ${runner?.bibNumber ?? ''}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.mediumColor)),
              ],
            ),
          ),
          Text(
            result.finishTime == null
                ? ''
                : TimeFormatter.formatDuration(result.finishTime!),
            style: AppTypography.bodySemibold
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
