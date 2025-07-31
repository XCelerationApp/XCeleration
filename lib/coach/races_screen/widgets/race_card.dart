import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import '../controller/races_controller.dart';
import '../../race_screen/controller/race_screen_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/database/race.dart';
import '../../../core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:intl/intl.dart';

class RaceCard extends StatelessWidget {
  final Race race;
  final String flowState;
  final RacesController controller;
  late final String flowStateText;
  late final Color flowStateColor;

  RaceCard({
    super.key,
    required this.race,
    required this.flowState,
    required this.controller,
  }) {
    // State text based on flow state
    flowStateText = {
          Race.FLOW_SETUP: 'Setting up',
          Race.FLOW_SETUP_COMPLETED: 'Ready to Share',
          Race.FLOW_PRE_RACE: 'Sharing Runners',
          Race.FLOW_PRE_RACE_COMPLETED: 'Ready for Results',
          Race.FLOW_POST_RACE: 'Processing Results',
          Race.FLOW_FINISHED: 'Race Complete',
        }[race.flowState] ??
        'Setting up';

    // Different colors based on the flow state
    flowStateColor = {
          Race.FLOW_SETUP: ColorUtils.withOpacity(AppColors.primaryColor, 0.5),
          Race.FLOW_SETUP_COMPLETED:
              ColorUtils.withOpacity(AppColors.primaryColor, 0.5),
          Race.FLOW_PRE_RACE: AppColors.primaryColor,
          Race.FLOW_PRE_RACE_COMPLETED: AppColors.primaryColor,
          Race.FLOW_POST_RACE: AppColors.primaryColor,
          Race.FLOW_FINISHED: Colors.blue,
        }[race.flowState] ??
        AppColors.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: Key(race.raceId!.toString()),
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const DrawerMotion(),
        dragDismissible: false,
        children: [
          CustomSlidableAction(
            onPressed: (_) => controller.editRace(race),
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
                const SizedBox(height: 4),
                Text(
                  'Edit',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => controller.deleteRace(race),
            backgroundColor: Colors.red,
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
                const SizedBox(height: 4),
                Text(
                  'Delete',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: ColorUtils.withOpacity(AppColors.mediumColor, 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: AppColors.primaryColor,
              width: 5,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () async {
              final masterRace = MasterRace.getInstance(race.raceId!);
              await RaceController.showRaceScreen(
                  context, controller, masterRace);
            },
            child: Padding(
              padding: const EdgeInsets.only(
                  left: 24.0, right: 24.0, top: 16.0, bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          race.raceName!,
                          style: AppTypography.headerSemibold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: flowStateColor.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                flowStateColor.withAlpha((0.5 * 255).round()),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            race.location!,
                            style: AppTypography.bodyRegular
                                .copyWith(color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Only show date if not null
                  if (race.raceDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, y').format(race.raceDate!),
                          style: AppTypography.bodyRegular
                              .copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],

                  // Only show distance if greater than 0
                  if (race.distance != null && race.distance! > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.straighten_rounded,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${race.distance!} ${race.distanceUnit ?? ''}',
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
