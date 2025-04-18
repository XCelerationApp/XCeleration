import 'package:flutter/material.dart';
import 'package:xcelerate/shared/role_bar/role_bar.dart';
import '../../../shared/models/race.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../flows/widgets/flow_section_header.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/components/coach_mark.dart';
import '../controller/races_controller.dart';
import '../widgets/race_card.dart';
import '../widgets/race_tutorial_coach_mark.dart';
import 'package:provider/provider.dart';

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
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<RacesController>(
        builder: (context, controller, child) {
          return TutorialRoot(
            tutorialManager: controller.tutorialManager,
            child: Scaffold(
              floatingActionButton: CoachMark(
                id: 'create_race_button_tutorial',
                tutorialManager: controller.tutorialManager,
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
                  onPressed: () => controller.showCreateRaceSheet(context),
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
                      RoleBar(currentRole: Role.coach, tutorialManager: controller.tutorialManager),
                      RaceCoachMark(
                        controller: controller,
                        child: _buildRacesList(controller),
                      ),
                    ]
                  ),
                ),
              )
            )
          );
        },
      ),
    );
  }
  
  // Extracted method to build the races list
  Widget _buildRacesList(RacesController controller) {
    // Show loading indicator while races are being loaded
    if (controller.races.isEmpty) {
      return Center(
          child: Text('No races.',
              style: AppTypography.bodyRegular));
    }

    final List<Race> raceData = controller.races;
    final finishedRaces = raceData
        .where((race) => race.flowState == Race.FLOW_FINISHED)
        .toList();
    final raceInProgress = raceData
        .where((race) =>
            race.flowState == Race.FLOW_POST_RACE ||
            race.flowState == Race.FLOW_PRE_RACE ||
            race.flowState == Race.FLOW_PRE_RACE_COMPLETED ||
            race.flowState == Race.FLOW_POST_RACE_COMPLETED)
        .toList();
    final upcomingRaces = raceData
        .where((race) => race.flowState == Race.FLOW_SETUP || race.flowState == Race.FLOW_SETUP_COMPLETED)
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
                controller: controller)),
          ],
          if (upcomingRaces.isNotEmpty) ...[
            FlowSectionHeader(title: 'Upcoming'),
            ...upcomingRaces.map((race) => RaceCard(
                race: race,
                flowState: race.flowState,
                controller: controller)),
          ],
          if (finishedRaces.isNotEmpty) ...[
            FlowSectionHeader(title: 'Finished'),
            ...finishedRaces.map((race) => RaceCard(
                race: race,
                flowState: race.flowState,
                controller: controller)),
          ],
        ],
      ),
    );
  }
}
