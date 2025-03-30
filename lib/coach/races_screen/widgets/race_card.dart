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
    final flowStateText = {
      'setup': 'Setup Required',
      'pre-race': 'Pre-Race Setup',
      'post-race': 'Post-Race',
      'finished': 'Completed',
    }[race.flowState] ?? 'Setup Required';

    // final flowStateColor = {
    //   'setup': Colors.orange,
    //   'pre-race': Colors.blue,
    //   'post-race': Colors.purple,
    //   'finished': AppColors.primaryColor,
    // }[race.flowState] ?? Colors.orange;

    final flowStateColor = AppColors.primaryColor;

    // Updated color to match design
    const primaryColor = Color(0xFFE2572B);
    const backgroundColor = Color(0xFFFFF0EA);

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
          color: backgroundColor,
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
            onTap: () => RaceScreenController.showRaceScreen(context, race.race_id),
            child: Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 16.0),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: flowStateColor.withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: flowStateColor.withAlpha((0.5 * 255).round()),
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            race.location,
                            style: AppTypography.bodyRegular.copyWith(color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d, y').format(race.race_date),
                              style: AppTypography.bodyRegular.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.straighten_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${race.distance} ${race.distanceUnit}',
                              style: AppTypography.headerSemibold.copyWith(
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}