import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:intl/intl.dart';

class SpectatorRaceCard extends StatefulWidget {
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
  State<SpectatorRaceCard> createState() => _SpectatorRaceCardState();
}

class _SpectatorRaceCardState extends State<SpectatorRaceCard> {
  static final _dateFormat = DateFormat('MMM d, y');

  DateTime? _parsedDate;

  @override
  void initState() {
    super.initState();
    _parseDate();
  }

  @override
  void didUpdateWidget(SpectatorRaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.race['race_date'] != widget.race['race_date']) {
      _parseDate();
    }
  }

  void _parseDate() {
    final raceDate = widget.race['race_date'] as String?;
    if (raceDate != null) {
      try {
        _parsedDate = DateTime.parse(raceDate);
      } catch (_) {
        _parsedDate = null;
      }
    } else {
      _parsedDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raceName = widget.race['race_name'] as String? ?? 'Unnamed Race';
    final location = widget.race['location'] as String?;
    final distance = widget.race['distance'] as double?;
    final distanceUnit = widget.race['distance_unit'] as String?;

    return Slidable(
      key: Key(widget.race['id']?.toString() ?? 'unknown'),
      endActionPane: ActionPane(
        extentRatio: 0.5,
        motion: const DrawerMotion(),
        dragDismissible: false,
        children: [
          CustomSlidableAction(
            onPressed: (_) => widget.onShare(),
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
            onPressed: (_) => widget.onDelete(),
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
              color: AppColors.primaryColor, // Blue for finished races
              width: 5,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
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
                  if (_parsedDate != null) ...[
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
                          _dateFormat.format(_parsedDate!),
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
