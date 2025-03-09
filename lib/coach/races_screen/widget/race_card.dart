import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../race_screen/widget/race_status_indicator.dart';
import '../../../utils/date_formatter.dart';

class RaceCard extends StatelessWidget {
  final Map<String, dynamic> race;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  
  const RaceCard({
    Key? key,
    required this.race,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final name = race['name'] as String;
    final date = race['date'] as String;
    final location = race['location'] as String;
    final flowState = race['flow_state'] as String;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: AppTypography.bodySemibold.copyWith(
                        fontSize: 18,
                        color: AppColors.darkColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  RaceStatusIndicator(flowState: flowState),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppColors.darkColor.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDate(date),
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.darkColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.darkColor.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    location,
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.darkColor.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[400],
                    ),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
