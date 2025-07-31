import 'package:flutter/material.dart';
import 'package:xceleration/shared/role_bar/role_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/components/coach_mark.dart';
import '../controller/races_controller.dart';
import '../widgets/race_tutorial_coach_mark.dart';
import '../widgets/races_list.dart';

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return TutorialRoot(
            tutorialManager: _controller.tutorialManager,
            child: Scaffold(
                floatingActionButton: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main Create Race FAB
                    CoachMark(
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
                        heroTag: 'create_race',
                        onPressed: () =>
                            _controller.showCreateRaceSheet(context),
                        backgroundColor: AppColors.primaryColor,
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ],
                ),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RoleBar(
                              currentRole: Role.coach,
                              tutorialManager: _controller.tutorialManager),
                          RaceCoachMark(
                            controller: _controller,
                            child: RacesList(controller: _controller),
                          ),
                        ]),
                  ),
                )));
      },
    );
  }
}
