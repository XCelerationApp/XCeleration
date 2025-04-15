import 'package:flutter/material.dart';
import 'package:xcelerate/coach/races_screen/controller/races_controller.dart';
import '../../race_screen/controller/race_screen_controller.dart';
import '../../../shared/models/race.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class RaceCard extends StatelessWidget {
  final Race race;
  final String flowState;
  final RacesController controller;

  const RaceCard({
    super.key,
    required this.race,
    required this.flowState,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    // Updated flow state text with setup-completed state
    final flowStateText = {
          'setup': 'Runner Setup',
          'setup-completed': 'Ready to Share',
          'pre-race': 'Sharing Runners',
          'pre-race-completed': 'Ready for Results',
          'post-race': 'Processing Results',
          'post-race-completed': 'Ready to Finalize',
          'finished': 'Race Complete',
        }[race.flowState] ??
        'Runner Setup';

    // Different colors based on the flow state
    final flowStateColor = {
          'setup': AppColors.primaryColor.withOpacity(0.7),
          'setup-completed': AppColors.primaryColor.withOpacity(0.7),
          'pre-race': AppColors.primaryColor,
          'post-race': AppColors.primaryColor,
          'finished': Colors.blue,
        }[race.flowState] ??
        AppColors.primaryColor;

    return Slidable(
      key: Key(race.race_id.toString()),
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
          color: AppColors.lightColor.withOpacity(.5),
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
            onTap: () =>
                RaceScreenController.showRaceScreen(context, race.race_id),
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
                          race.raceName,
                          style: AppTypography.headerSemibold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              flowStateColor.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                flowStateColor.withAlpha((0.5 * 255).round()),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          flowStateText,
                          style: TextStyle(
                            color: flowStateColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Only show location if not empty
                  if (race.location.isNotEmpty) ...[
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
                            race.location,
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
                  if (race.race_date != null) ...[
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
                          DateFormat('MMM d, y').format(race.race_date!),
                          style: AppTypography.bodyRegular
                              .copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                  
                  // Only show distance if greater than 0
                  if (race.distance > 0) ...[
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
                          '${race.distance} ${race.distanceUnit}',
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
