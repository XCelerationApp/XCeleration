import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/components/button_components.dart';
import '../../../utils/database_helper.dart';
import 'competing_teams_field.dart';
import 'modern_detail_row.dart';
import '../controller/race_screen_controller.dart';
import 'race_name_field.dart';
import 'race_location_field.dart';
import 'race_date_field.dart';
import 'race_distance_field.dart';
import 'package:provider/provider.dart';

class RaceDetailsTab extends StatefulWidget {
  final RaceController controller;
  const RaceDetailsTab({super.key, required this.controller});

  @override
  State<RaceDetailsTab> createState() => _RaceDetailsTabState();
}

class _RaceDetailsTabState extends State<RaceDetailsTab> {
  bool detailsChanged = false;
  bool _showingRunners = false;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _teamsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
  
  @override
  void dispose() {
    _dateController.dispose();
    _locationController.dispose();
    _distanceController.dispose();
    _unitController.dispose();
    _teamsController.dispose();
    super.dispose();
  }
  
  void _initializeControllers() {
    final race = widget.controller.race!;
    _dateController.text = race.raceDate != null 
        ? DateFormat('yyyy-MM-dd').format(race.raceDate!) 
        : '';
    _locationController.text = race.location;
    _distanceController.text = race.distance > 0 ? race.distance.toString() : '';
    _unitController.text = race.distanceUnit.isNotEmpty ? race.distanceUnit : 'mi';
    _teamsController.text = race.teams.join(', ');
  }
  
  void _toggleView() {
    setState(() {
      _showingRunners = !_showingRunners;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.controller,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final race = widget.controller.race!;
          final isSetup = race.flowState == 'setup';
          final hasTeams = race.teams.isNotEmpty;
          int runnerCount = 0;
          
        return FutureBuilder(
          future: DatabaseHelper.instance.getRaceRunners(race.raceId),
          builder: (context, snapshot) {
            // Default value for runners count
            runnerCount = snapshot.hasData ? (snapshot.data as List).length : runnerCount;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Details section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Race Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Form fields using new components
                      isSetup
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RaceNameField(
                                  controller: widget.controller,
                                  setSheetState: setState,
                                  onChanged: (_) {
                                    setState(() {
                                      detailsChanged = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                RaceLocationField(
                                  controller: widget.controller,
                                  setSheetState: setState,
                                  onChanged: (_) {
                                    setState(() {
                                      detailsChanged = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                RaceDateField(
                                  controller: widget.controller,
                                  setSheetState: setState,
                                  onChanged: (_) {
                                    setState(() {
                                      detailsChanged = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                RaceDistanceField(
                                  controller: widget.controller,
                                  setSheetState: setState,
                                  onChanged: (_) {
                                    setState(() {
                                      detailsChanged = true;
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                CompetingTeamsField(
                                  controller: widget.controller,
                                  setSheetState: setState,
                                  onChanged: (_) {
                                    setState(() {
                                      detailsChanged = true;
                                    });
                                  },
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ModernDetailRow(
                                  label: 'Race Name',
                                  value: race.raceName,
                                  icon: Icons.emoji_events,
                                ),
                                const SizedBox(height: 12),
                                ModernDetailRow(
                                  label: 'Location',
                                  value: race.location,
                                  icon: Icons.location_on,
                                ),
                                const SizedBox(height: 12),
                                ModernDetailRow(
                                  label: 'Race Date',
                                  value: race.raceDate != null
                                      ? DateFormat('yyyy-MM-dd').format(race.raceDate!)
                                      : 'Not set',
                                  icon: Icons.calendar_today,
                                ),
                                const SizedBox(height: 12),
                                ModernDetailRow(
                                  label: 'Distance',
                                  value: '${race.distance} ${race.distanceUnit}',
                                  icon: Icons.straighten,
                                ),
                                const SizedBox(height: 12),
                                ModernDetailRow(
                                  label: 'Teams',
                                  value: race.teams.join(', '),
                                  icon: Icons.groups,
                                ),
                              ],
                            ),
                      const SizedBox(height: 16),
                      // Clickable runners row with chevron - using custom layout
                      InkWell(
                        onTap: widget.controller.race?.flowState == 'finished' ? _toggleView : null,
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
                                      '$runnerCount runner${runnerCount == 1 ? '' : 's'}',
                                      style: AppTypography.bodySemibold.copyWith(
                                        color: AppColors.darkColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Chevron icon - only show when race is finished
                              if (widget.controller.race?.flowState == 'finished')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right,
                                      color: AppColors.primaryColor,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              if (isSetup && hasTeams) ...[
                                SecondaryButton(
                                  text: 'Load Runners',
                                  icon: Icons.person_add,
                                  onPressed: () => widget.controller.loadRunnersManagementScreen(context),
                                ),
                              ]

                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                  // Add Save Changes button at the bottom when in setup mode
                  if (isSetup) ...[
                    const SizedBox(height: 24),
                    FullWidthButton(
                      text: 'Save Changes',
                      onPressed: () {
                        setState(() {
                          detailsChanged = false;
                        });
                        widget.controller.saveRaceDetails(context);
                      },
                      isEnabled: detailsChanged,
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
