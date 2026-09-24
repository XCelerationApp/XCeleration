import 'package:flutter/material.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/components/app_header.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../shared/role_bar/widgets/instructions_banner.dart';
import '../../../shared/role_bar/widgets/role_selector_sheet.dart';
import '../../../shared/settings_screen.dart';
import '../../../core/utils/enums.dart';
import '../widgets/race_controls_widget.dart';
import '../widgets/race_status_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import '../controller/timing_controller.dart';
import '../../shared/services/assistant_storage_service.dart';
import '../widgets/records_list_widget.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../shared/widgets/race_header_widget.dart';
import '../../../core/components/coach_mark.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
        // While the clock runs, the header and practice banner give way so
        // the times and the Log Finish button have the room.
        body: ListenableBuilder(
          listenable: _raceStateAndInfo,
          builder: (context, _) {
            final live =
                _controller.startTime != null && !_controller.raceStopped;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (live)
                  SizedBox(height: MediaQuery.paddingOf(context).top)
                else
                  AppHeader(
                    title: 'Race Timer',
                    currentRole: Role.timer,
                    tutorialManager: tutorialManager,
                    onRoleTap: () => RoleSelectorSheet.showRoleSelection(
                        context, Role.timer),
                    onSettingsTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          currentRole: Role.timer.toValueString(),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRaceHeader(context, live),
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
                      const SizedBox(height: AppSpacing.sm),
                      ListenableBuilder(
                        listenable: _raceStateAndRecords,
                        builder: (context, child) =>
                            RaceStatusWidget(controller: _controller),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // Records list: rebuilds only when records change.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: ListenableBuilder(
                      listenable: _controller.recordsSignal,
                      builder: (context, child) =>
                          RecordsListWidget(controller: _controller),
                    ),
                  ),
                ),
                // The thumb area: Start, Log Finish, or Share Times.
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                    child: ListenableBuilder(
                      listenable: _raceStateAndRecords,
                      builder: (context, child) =>
                          RaceControlsWidget(controller: _controller),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRaceHeader(BuildContext context, bool live) {
    // Race header: only rebuilds when the loaded race changes
    return ListenableBuilder(
      listenable: _controller.raceInfoSignal,
      builder: (context, child) {
        return CoachMark(
          id: 'race_header_tutorial',
          tutorialManager: tutorialManager,
          config: const CoachMarkConfig(
            title: 'Race Information',
            description:
                'This shows your current race. A practice race is loaded so you can try things out. Tap Get Race from Coach for the real one.',
            icon: Icons.info_outline,
            alignmentY: AlignmentY.bottom,
            type: CoachMarkType.targeted,
            backgroundColor: Color(0xFF1976D2),
          ),
          child: RaceHeaderWidget(
            currentRace: _controller.currentRace,
            role: DeviceName.raceTimer,
            compact: live,
            onLoadRace: () => _controller.showLoadRaceSheet(context),
            onShowOtherRaces: () => _controller.showOtherRaces(context),
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
              final confirmed = await DialogUtils.showConfirmationDialog(
                context,
                title: 'Clear Race Times',
                content: 'This removes every time logged for this race.',
                confirmText: 'Clear Times',
                cancelText: 'Cancel',
                destructive: true,
              );
              if (confirmed && context.mounted) {
                await _controller.doClearRaceTimes();
              }
            },
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
