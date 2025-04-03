import 'package:flutter/material.dart';
import 'package:xcelerate/shared/settings_screen.dart';
import '../../../shared/models/race.dart';
import '../../../core/theme/app_colors.dart';
import '../../flows/widgets/flow_section_header.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/components/coach_mark.dart';
import '../controller/races_controller.dart';
import '../widgets/race_card.dart';
import '../widgets/race_tutorial_coach_mark.dart';

class RacesScreen extends StatefulWidget {
  const RacesScreen({super.key});

  @override
  RacesScreenState createState() => RacesScreenState();
}

class RacesScreenState extends State<RacesScreen> {
  final RacesController _controller = RacesController();

  @override
  void initState() {
    super.initState();
    _controller.setContext(context);
    _controller.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TutorialRoot(
        tutorialManager: _controller.tutorialManager,
        child: Scaffold(
            floatingActionButton: CoachMark(
              id: 'create_race_button_tutorial',
              tutorialManager: _controller.tutorialManager,
              config: const CoachMarkConfig(
                title: 'Create Race',
                alignmentX: AlignmentX.left,
                alignmentY: AlignmentY.top,
                description: 'Click here to create a new race',
                icon: Icons.add,
                type: CoachMarkType.targeted,
                backgroundColor: Color(0xFF1976D2),
                elevation: 12,
              ),
              child: FloatingActionButton(
                onPressed: () => _controller.showCreateRaceSheet(context),
                // tooltip: 'Create new race',
                backgroundColor: AppColors.primaryColor,
                child: Icon(Icons.add),
              ),
            ),
            body: Padding(
              padding: EdgeInsets.fromLTRB(24.0, 56.0, 24.0, 24.0),
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Races',
                            style: AppTypography.displaySmall,
                          ),
                          Row(children: [
                            CoachMark(
                              id: 'settings_button_tutorial',
                              tutorialManager: _controller.tutorialManager,
                              config: const CoachMarkConfig(
                                title: 'Settings',
                                alignmentX: AlignmentX.left,
                                alignmentY: AlignmentY.bottom,
                                description: 'Click here to open settings',
                                icon: Icons.settings,
                                type: CoachMarkType.targeted,
                                backgroundColor: Color(0xFF1976D2),
                                elevation: 12,
                              ),
                              child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) => SettingsScreen(
                                              currentRole: 'coach')),
                                    );
                                  },
                                  child: Icon(Icons.settings,
                                      color: AppColors.darkColor, size: 36)),
                            )
                          ]),
                        ],
                      ),
                      RaceCoachMark(
                        controller: _controller,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            // Show loading indicator while races are being loaded
                            if (_controller.races.isEmpty) {
                              return Center(
                                  child: Text('No races found.',
                                      style: AppTypography.bodyRegular));
                            }

                            final List<Race> raceData = _controller.races;
                            final finishedRaces = raceData
                                .where((race) => race.flowState == 'finished')
                                .toList();
                            final raceInProgress = raceData
                                .where((race) =>
                                    race.flowState == 'post-race' ||
                                    race.flowState == 'pre-race')
                                .toList();
                            final upcomingRaces = raceData
                                .where((race) => race.flowState == 'setup')
                                .toList();
                            return SingleChildScrollView(
                              controller: ScrollController(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (raceInProgress.isNotEmpty) ...[
                                    FlowSectionHeader(title: 'In Progress'),
                                    ...raceInProgress.map((race) => RaceCard(
                                        race: race,
                                        flowState: race.flowState,
                                        controller: _controller)),
                                  ],
                                  if (upcomingRaces.isNotEmpty) ...[
                                    FlowSectionHeader(title: 'Upcoming'),
                                    ...upcomingRaces.map((race) => RaceCard(
                                        race: race,
                                        flowState: race.flowState,
                                        controller: _controller)),
                                  ],
                                  if (finishedRaces.isNotEmpty) ...[
                                    FlowSectionHeader(title: 'Finished'),
                                    ...finishedRaces.map((race) => RaceCard(
                                        race: race,
                                        flowState: race.flowState,
                                        controller: _controller)),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ]),
              ),
            )));
  }
}
