import 'package:flutter/material.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/components/app_header.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../shared/role_bar/widgets/instructions_banner.dart';
import '../../../shared/role_bar/widgets/role_selector_sheet.dart';
import '../../../shared/settings_screen.dart';
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
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';

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
  late final Listenable _raceStateAndRecords;
  late final Listenable _raceStateAndInfo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = TimingController(
      storage: AssistantStorageService.instance,
      audioPlayer: AudioPlayer(),
    );
    _raceStateAndRecords = Listenable.merge([
      _controller.raceStateSignal,
      _controller.recordsSignal,
    ]);
    _raceStateAndInfo = Listenable.merge([
      _controller.raceStateSignal,
      _controller.raceInfoSignal,
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InstructionsBanner.showInstructionsSheet(context, Role.timer).then((_) {
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppHeader(
              title: 'Race Timer',
              currentRole: Role.timer,
              tutorialManager: tutorialManager,
              onRoleTap: () =>
                  RoleSelectorSheet.showRoleSelection(context, Role.timer),
              onSettingsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    currentRole: Role.timer.toValueString(),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Race header: only rebuilds when the loaded race changes
              ListenableBuilder(
                listenable: _controller.raceInfoSignal,
                builder: (context, child) {
                  return CoachMark(
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
                      clearRecordsLabel: 'Clear Times',
                      canClearRecords: () =>
                          _controller.raceStopped && _controller.hasTimingData,
                      onClearRecords: () async {
                        final confirmed =
                            await DialogUtils.showConfirmationDialog(
                          context,
                          title: 'Clear Race Times',
                          content:
                              'Are you sure you want to clear all race times?',
                        );
                        if (confirmed && context.mounted) {
                          await _controller.doClearRaceTimes();
                        }
                      },
                    ),
                  );
                },
              ),
              // Why the race could not be opened, if it failed to load.
              ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  final error = _controller.loadError;
                  if (error == null) return const SizedBox.shrink();
                  return _LoadErrorBanner(
                    message: error.userMessage,
                    onRetry: _controller.retryLoad,
                  );
                },
              ),
              const SizedBox(height: 8),
              // Race status: rebuilds when race state or records change
              ListenableBuilder(
                listenable: _raceStateAndRecords,
                builder: (context, child) {
                  return RaceStatusWidget(controller: _controller);
                },
              ),
              const SizedBox(height: 8),
              // Timer display: rebuilds when race running state changes
              ListenableBuilder(
                listenable: _controller.raceStateSignal,
                builder: (context, child) {
                  return TimerDisplayWidget(controller: _controller);
                },
              ),
              const SizedBox(height: 8),
              // Race controls: rebuilds when race state or race identity changes
              ListenableBuilder(
                listenable: _raceStateAndInfo,
                builder: (context, child) {
                  return RaceControlsWidget(controller: _controller);
                },
              ),
              Expanded(
                // Records list: rebuilds only when records change, not on race start/stop
                child: ListenableBuilder(
                  listenable: _controller.recordsSignal,
                  builder: (context, child) {
                    return RecordsListWidget(controller: _controller);
                  },
                ),
              ),
              // Bottom controls: rebuilds when race state or records change
              ListenableBuilder(
                listenable: _raceStateAndRecords,
                builder: (context, child) {
                  if (_controller.raceStopped == false &&
                      _controller.hasTimingData) {
                    return BottomControlsWidget(controller: _controller);
                  }
                  return const SizedBox.shrink();
                },
              ),
                  ],
                ),
              ),
            ),
          ],
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

class _LoadErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.redColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.redColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.redColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.darkColor)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
