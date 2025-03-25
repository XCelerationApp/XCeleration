import 'package:flutter/material.dart';
import 'modern_detail_row.dart';
import '../controller/race_screen_controller.dart';

class RaceDetailsTab extends StatelessWidget {
  final RaceScreenController controller;
  const RaceDetailsTab({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModernDetailRow(
            label: 'Date',
            value: controller.race!.race_date.toString().split(' ')[0],
            icon: Icons.calendar_today_rounded,
          ),
          const SizedBox(height: 16),
          ModernDetailRow(
            label: 'Location',
            value: controller.race!.location,
            icon: Icons.location_on_rounded,
            isMultiLine: true,
          ),
          const SizedBox(height: 16),
          ModernDetailRow(
            label: 'Distance',
            value: '${controller.race!.distance} ${controller.race!.distanceUnit}',
            icon: Icons.straighten_rounded,
          ),
          const SizedBox(height: 16),
          ModernDetailRow(
            label: 'Teams',
            value: controller.race!.teams.join(', '),
            icon: Icons.group_rounded,
          ),
        ],
      ),
    );
  }
}