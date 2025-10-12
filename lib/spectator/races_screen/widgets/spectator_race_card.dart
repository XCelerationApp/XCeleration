import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:intl/intl.dart';

class SpectatorRaceCard extends StatelessWidget {
  final Map<String, dynamic> race;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const SpectatorRaceCard({
    super.key,
    required this.race,
    required this.onTap,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final raceName = race['race_name'] as String? ?? 'Unnamed Race';
    final raceDate = race['race_date'] as String?;
    final location = race['location'] as String?;
    final distance = race['distance'] as double?;
    final distanceUnit = race['distance_unit'] as String?;

    DateTime? parsedDate;
    if (raceDate != null) {
      try {
        parsedDate = DateTime.parse(raceDate);
      } catch (_) {
        // Invalid date format
      }
    }

    return Slidable(
      key: Key(race['id']?.toString() ?? 'unknown'),
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const DrawerMotion(),
        dragDismissible: false,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onShare(),
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            autoClose: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Share',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            autoClose: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
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
              color: Colors.blue, // Blue for finished races
              width: 5,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
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
                          raceName,
                          style: AppTypography.headerSemibold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.withAlpha((0.5 * 255).round()),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Finished',
                          style: AppTypography.smallBodySemibold.copyWith(
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Only show location if not empty
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
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
                  if (parsedDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, y').format(parsedDate),
                          style: AppTypography.bodyRegular
                              .copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],

                  // Only show distance if greater than 0
                  if (distance != null && distance > 0) ...[
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
                          '$distance ${distanceUnit ?? ''}',
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
