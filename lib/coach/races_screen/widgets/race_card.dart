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

    final flowStateColor = {
      'setup': Colors.orange,
      'pre-race': Colors.blue,
      'post-race': Colors.purple,
      'finished': Colors.green,
    }[race.flowState] ?? Colors.orange;

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
                  style: AppTypography.smallBodyRegular,
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => controller.deleteRace(race),
            backgroundColor: AppColors.primaryColor.withRed(255),
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
                  style: AppTypography.smallBodyRegular,
                ),
              ],
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: double.infinity,
        child: Card(
          color: race.flowState == 'finished' ? const Color(0xFFBBDB86): const Color(0xFFE8C375),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => RaceScreenController.showRaceScreen(context, race.race_id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                      const Icon(Icons.location_on, size: 16, color: AppColors.darkColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          race.location,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyRegular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppColors.darkColor),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, y').format(race.race_date),
                        style: AppTypography.bodyRegular,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.directions_run, size: 16, color: AppColors.darkColor),
                          const SizedBox(width: 4),
                          Text(
                            '${race.distance} ${race.distanceUnit}',
                            style: AppTypography.bodyRegular,
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
    );
  }
}