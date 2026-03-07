import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../controller/races_controller.dart';
import '../../race_screen/controller/race_screen_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/typography.dart';
import 'package:intl/intl.dart';

class RaceCard extends StatelessWidget {
  final Race race;
  final String flowState;
  final RacesController controller;
  final bool canEdit;
  late final String flowStateText;
  late final Color flowStateColor;

  RaceCard({
    super.key,
    required this.race,
    required this.flowState,
    required this.controller,
    this.canEdit = true,
  }) {
    // State text based on flow state
    flowStateText = {
          Race.FLOW_SETUP: 'Setting up',
          Race.FLOW_SETUP_COMPLETED: 'Ready to Share',
          Race.FLOW_PRE_RACE: 'Sharing Race',
          Race.FLOW_PRE_RACE_COMPLETED: 'Ready for Results',
          Race.FLOW_POST_RACE: 'Processing Results',
          Race.FLOW_FINISHED: 'Race Complete',
        }[race.flowState] ??
        'Setting up';

    // Different colors based on the flow state
    flowStateColor = {
          Race.FLOW_SETUP:
              AppColors.primaryColor.withValues(alpha: AppOpacity.solid),
          Race.FLOW_SETUP_COMPLETED:
              AppColors.primaryColor.withValues(alpha: AppOpacity.solid),
          Race.FLOW_PRE_RACE: AppColors.primaryColor,
          Race.FLOW_PRE_RACE_COMPLETED: AppColors.primaryColor,
          Race.FLOW_POST_RACE: AppColors.primaryColor,
          Race.FLOW_FINISHED: AppColors.statusFinished,
        }[race.flowState] ??
        AppColors.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(race.raceId?.toString() ?? 'unknown'),
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const DrawerMotion(),
        dragDismissible: false,
        children: [
          if (canEdit)
            CustomSlidableAction(
              onPressed: (context) => controller.editRace(race, context),
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              autoClose: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Edit',
                    style:
                        AppTypography.bodySmall.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          if (canEdit)
            CustomSlidableAction(
              onPressed: (context) => controller.deleteRace(race, context),
              backgroundColor: AppColors.redColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              autoClose: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 24,
                    color: Colors.white,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Delete',
                    style:
                        AppTypography.bodySmall.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.mediumColor.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border(
            left: BorderSide(
              color: AppColors.primaryColor,
              width: 5,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          child: InkWell(
            onTap: () async {
              final masterRace = MasterRace.getInstance(race.raceId ?? 0);
              await RaceController.showRaceScreen(
                context,
                controller,
                masterRace,
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          race.raceName ?? 'Unnamed Race',
                          style: AppTypography.headerSemibold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: flowStateColor.withValues(alpha: AppOpacity.light),
                          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                          border: Border.all(
                            color:
                                flowStateColor.withValues(alpha: AppOpacity.solid),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          flowStateText,
                          style: AppTypography.smallBodySemibold.copyWith(
                            color: flowStateColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Only show location if not empty
                  if (race.location != null && race.location!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            race.location ?? '',
                            style: AppTypography.bodyRegular
                                .copyWith(color: AppColors.mediumColor),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Only show date if not null
                  if (race.raceDate != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          DateFormat('MMM d, y')
                              .format(race.raceDate ?? DateTime.now()),
                          style: AppTypography.bodyRegular
                              .copyWith(color: AppColors.mediumColor),
                        ),
                      ],
                    ),
                  ],

                  // Only show distance if greater than 0
                  if (race.distance != null && race.distance! > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten_rounded,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${race.distance ?? 0} ${race.distanceUnit ?? ''}',
                          style: AppTypography.headerSemibold.copyWith(
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
