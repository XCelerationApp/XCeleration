import 'package:flutter/material.dart';
import 'package:xcelerate/coach/runners_management_screen/screen/runners_management_screen.dart';
import 'package:xcelerate/utils/sheet_utils.dart';import '../../../utils/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import 'modern_detail_row.dart';
import '../controller/race_screen_controller.dart';

class RaceDetailsTab extends StatefulWidget {
  final RaceScreenController controller;
  const RaceDetailsTab({super.key, required this.controller});

  @override
  State<RaceDetailsTab> createState() => _RaceDetailsTabState();
}

class _RaceDetailsTabState extends State<RaceDetailsTab> {
  bool _showingRunners = false;

  void _toggleView() {
    setState(() {
      _showingRunners = !_showingRunners;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_showingRunners) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with back button
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          //   child: InkWell(
          //     onTap: _toggleView,
          //     child: Row(
          //       children: [
          //         Icon(
          //           Icons.arrow_back_ios,
          //           color: Theme.of(context).primaryColor,
          //         ),
          //         const SizedBox(width: 8),
          //         Text(
          //           'Back to race details',
          //           style: TextStyle(
          //             fontSize: 16,
          //             fontWeight: FontWeight.w500,
          //             color: Theme.of(context).primaryColor,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
          Align(
            alignment: Alignment.centerLeft,
            child: createBackArrow(context, onBack: _toggleView),
          ),
          // Embedded runners management screen
          RunnersManagementScreen(
              raceId: widget.controller.race!.raceId,
              showHeader: false, // Hide the header since we have our own back button
          ),
        ],
      );
    }

    return FutureBuilder(
      future: DatabaseHelper.instance.getRaceRunners(widget.controller.race!.raceId),
      builder: (context, snapshot) {
        // Default value for runners count
        final runnerCount = snapshot.hasData ? (snapshot.data as List).length : 0;
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ModernDetailRow(
                label: 'Date',
                value: widget.controller.race!.race_date.toString().split(' ')[0],
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 16),
              ModernDetailRow(
                label: 'Location',
                value: widget.controller.race!.location,
                icon: Icons.location_on_rounded,
                isMultiLine: true,
              ),
              const SizedBox(height: 16),
              ModernDetailRow(
                label: 'Distance',
                value:
                    '${widget.controller.race!.distance} ${widget.controller.race!.distanceUnit}',
                icon: Icons.straighten_rounded,
              ),
              const SizedBox(height: 16),
              ModernDetailRow(
                label: 'Teams',
                value: widget.controller.race!.teams.join(', '),
                icon: Icons.group_rounded,
              ),
              const SizedBox(height: 16),
              // Clickable runners row with chevron - using custom layout
              InkWell(
                onTap: _toggleView,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      // Icon container - same style as ModernDetailRow
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.group_rounded, 
                          color: AppColors.primaryColor, 
                          size: 22
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content area
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Runners',
                              style: AppTypography.bodyRegular.copyWith(
                                color: AppColors.darkColor.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              snapshot.connectionState == ConnectionState.waiting 
                                ? 'Loading...' 
                                : '$runnerCount runners',
                              style: AppTypography.bodySemibold.copyWith(
                                color: AppColors.darkColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Chevron icon - explicitly positioned
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.primaryColor,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
