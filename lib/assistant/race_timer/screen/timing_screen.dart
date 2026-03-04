import 'package:flutter/material.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../shared/role_bar/role_bar.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/utils/enums.dart';
import '../widgets/timer_display_widget.dart';
import '../widgets/race_controls_widget.dart';
import '../widgets/race_status_widget.dart';
import '../widgets/bottom_controls_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import '../controller/timing_controller.dart';
import '../../shared/services/assistant_storage_service.dart';
import '../widgets/records_list_widget.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../shared/widgets/race_header_widget.dart';
import '../../../core/components/coach_mark.dart';

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
    _controller = TimingController(
      storage: AssistantStorageService.instance,
      audioPlayer: AudioPlayer(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      RoleBar.showInstructionsSheet(context, Role.timer).then((_) {
        if (context.mounted) _setupTutorials();
      });
    });
  }

  void _setupTutorials() {
    tutorialManager.startTutorial([
      'race_header_tutorial',
      'role_bar_tutorial',
    ]);
  }

  @override
  Widget build(BuildContext context) {
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
              // Only rebuild the parts that depend on controller state
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CoachMark(
                        id: 'race_header_tutorial',
                        tutorialManager: tutorialManager,
                        config: const CoachMarkConfig(
                          title: 'Race Information',
                          description:
                              'This shows your current race. A demo race has been loaded so you can test the features. Tap the menu to load a race from your coach.',
                          icon: Icons.info_outline,
                          alignmentY: AlignmentY.bottom,
                          type: CoachMarkType.targeted,
                          backgroundColor: Color(0xFF1976D2),
                        ),
                        child: RaceHeaderWidget(
                          currentRace: _controller.currentRace,
                          role: DeviceName.raceTimer,
                          onLoadRace: () =>
                              _controller.showLoadRaceSheet(context),
                          onShowOtherRaces: () =>
                              _controller.showOtherRaces(context),
                          onDeleteRace: () async {
                            final error = await _controller.deleteCurrentRace();
                            if (error != null && context.mounted) {
                              DialogUtils.showErrorDialog(context,
                                  message: error.userMessage);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      RaceStatusWidget(controller: _controller),
                      const SizedBox(height: 8),
                      TimerDisplayWidget(
                        controller: _controller,
                      ),
                      const SizedBox(height: 8),
                      RaceControlsWidget(controller: _controller),
                      if (_controller.hasTimingData) const SizedBox(height: 30),
                    ],
                  );
                },
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return RecordsListWidget(controller: _controller);
                  },
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  if (_controller.raceStopped == false &&
                      _controller.hasTimingData) {
                    return BottomControlsWidget(
                      controller: _controller,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
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
