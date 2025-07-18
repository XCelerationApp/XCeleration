import 'package:flutter/material.dart';
import '../../../shared/role_bar/role_bar.dart';
import '../../../core/services/tutorial_manager.dart';
import '../widgets/timer_display_widget.dart';
import '../widgets/race_controls_widget.dart';
import '../widgets/race_info_header_widget.dart';
import '../widgets/bottom_controls_widget.dart';
import '../controller/timing_controller.dart';
import '../widgets/records_list_widget.dart';
import '../../../shared/role_bar/models/role_enums.dart';

class TimingScreen extends StatefulWidget {
  const TimingScreen({super.key});

  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen>
    with TickerProviderStateMixin {
  late TimingController _controller;
  late TabController _tabController;
  late final TutorialManager tutorialManager = TutorialManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = TimingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      RoleBar.showInstructionsSheet(context, Role.timer).then((_) {
        if (context.mounted) _setupTutorials();
      });
    });
  }

  void _setupTutorials() {
    tutorialManager.startTutorial([
      // 'swipe_tutorial',
      'role_bar_tutorial',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Set the context in the controller for dialog management
    _controller.setContext(context);

    // Use AnimatedBuilder to rebuild when the controller changes
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return TutorialRoot(
          tutorialManager: tutorialManager,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RoleBar(
                    currentRole: Role.timer,
                    tutorialManager: tutorialManager,
                  ),
                  const SizedBox(height: 16),
                  RaceInfoHeaderWidget(controller: _controller),
                  const SizedBox(height: 8),
                  TimerDisplayWidget(
                    controller: _controller,
                  ),
                  const SizedBox(height: 8),
                  RaceControlsWidget(controller: _controller),
                  if (_controller.hasTimingData)
                    const SizedBox(height: 30),
                  Expanded(child: RecordsListWidget(controller: _controller)),
                  if (_controller.raceStopped == false &&
                      _controller.hasTimingData)
                    BottomControlsWidget(
                      controller: _controller,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    tutorialManager.dispose();
    super.dispose();
  }
}
