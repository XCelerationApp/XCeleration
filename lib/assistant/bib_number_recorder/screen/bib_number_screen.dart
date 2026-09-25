import 'package:flutter/material.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/screen_awake.dart';
import '../../shared/utils/live_race_screen.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/utils/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../shared/role_bar/widgets/role_selector_sheet.dart';
import '../../../shared/settings_screen.dart';
import '../../../core/components/app_header.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/role_bar/widgets/instructions_banner.dart';
import '../controller/bib_number_controller.dart';
import '../../shared/models/race_record.dart';
import '../widgets/bib_list_widget.dart';
import '../widgets/race_controls_widget.dart';
import '../widgets/keyboard_accessory_bar.dart';
import '../widgets/voice_entry_panel.dart';
import '../controller/voice_entry_controller.dart';
import '../widgets/runners_loaded_sheet.dart';
import '../../shared/widgets/race_header_widget.dart';
import '../../../core/theme/app_spacing.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../../../core/components/coach_mark.dart';

class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key, required this.controller});

  final BibNumberController controller;

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  late BibNumberController _controller;
  late final VoiceEntryController _voice;

  /// Saves the bib being typed when the app goes to the background. Typed
  /// bibs are saved as their row loses focus, so a bib half entered when the
  /// phone was locked or the app swiped away was lost.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onControllerChanged);
    _voice = VoiceEntryController(
      onBibHeard: _controller.addHeardBib,
      // Settles sound-alikes ("to" or "two") by who is running.
      isKnownBib: (bib) => _controller.getRunnerByBib(bib) != null,
    );
    _voice.restore();
    _lifecycle = AppLifecycleListener(onInactive: _controller.saveNow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      InstructionsBanner.showInstructionsSheet(context, Role.bibRecorder).then((_) {
        if (mounted) _controller.setupTutorials();
      });
    });
  }

  void _onControllerChanged() {
    // The screen stays on while recording, and is reopened if the app
    // closes mid-race.
    final live = _controller.currentRace != null && !_controller.raceStopped;
    ScreenAwake.set(live);
    LiveRaceScreen.mark(live ? LiveRaceScreen.bibRecorder : null);
    if (_controller.runnersJustLoaded) {
      _controller.clearRunnersJustLoaded();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        sheet(
          context: context,
          title: 'Loaded Runners',
          body: RunnersLoadedSheet(runners: _controller.runners),
        );
      });
    }
  }

  Future<void> _onShareBibNumbers() async {
    for (var node in _controller.focusNodes) {
      node.unfocus();
      node.canRequestFocus = false;
    }

    final result = await _controller.prepareShareData();
    if (!mounted) return;

    switch (result) {
      case ShareDataDemoRace():
        DialogUtils.showMessageDialog(
          context,
          title: 'Demo Race',
          message:
              'The demo race is for practice only and cannot be shared. Please load a real race from your coach to share results.',
        );
        _controller.restoreFocusability();
      case ShareDataHasDuplicates(:final duplicates, :final hasUnknown, :final encodedData):
        final okDupes = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Duplicate Bib Numbers',
          content:
              'There are duplicate bib numbers in the list: ${duplicates.join(', ')}. Do you want to continue?',
        );
        if (!mounted) return;
        if (!okDupes) {
          _controller.restoreFocusability();
          return;
        }
        if (hasUnknown) {
          final okUnknown = await DialogUtils.showConfirmationDialog(
            context,
            title: 'Unknown Bib Numbers',
            content:
                'There are bib numbers in the list that do not match any runners in the database. Do you want to continue?',
          );
          if (!mounted) return;
          if (!okUnknown) {
            _controller.restoreFocusability();
            return;
          }
        }
        _controller.showShareBibNumbersSheet(context, encodedData);
        _controller.restoreFocusability();
      case ShareDataHasUnknown(:final encodedData):
        final ok = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Unknown Bib Numbers',
          content:
              'There are bib numbers in the list that do not match any runners in the database. Do you want to continue?',
        );
        if (!mounted) return;
        if (!ok) {
          _controller.restoreFocusability();
          return;
        }
        _controller.showShareBibNumbersSheet(context, encodedData);
        _controller.restoreFocusability();
      case ShareDataReady(:final encodedData):
        _controller.showShareBibNumbersSheet(context, encodedData);
        _controller.restoreFocusability();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _lifecycle.dispose();
    _voice.dispose();
    ScreenAwake.set(false);
    LiveRaceScreen.mark(null);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: TutorialRoot(
        tutorialManager: _controller.tutorialManager,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            // While recording, the big header and practice banner give way
            // so the bibs being typed stay in view above the number pad.
            body: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final live =
                    _controller.currentRace != null && !_controller.raceStopped;
                return Column(children: [
                  if (live)
                    SizedBox(height: MediaQuery.paddingOf(context).top)
                  else
                    AppHeader(
                      title: 'Bib Recorder',
                      currentRole: Role.bibRecorder,
                      tutorialManager: _controller.tutorialManager,
                      titleStyle: AppTypography.displaySmall,
                      onRoleTap: () => RoleSelectorSheet.showRoleSelection(
                          context, Role.bibRecorder),
                      onSettingsTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            currentRole: Role.bibRecorder.toValueString(),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildRaceHeader(context, live),
                          const SizedBox(height: AppSpacing.sm),
                          _buildRaceStatusWidget(),
                        ]),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // BibListWidget manages its own listener.
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: BibListWidget(controller: _controller),
                    ),
                  ),

                  // Next Bib above the number pad while typing; otherwise the
                  // big button in the thumb area.
                  ValueListenableBuilder<bool>(
                    valueListenable: _controller.keyboardVisibleNotifier,
                    builder: (context, keyboardUp, _) {
                      if (KeyboardAccessoryBar.isShowing(
                          _controller, keyboardUp)) {
                        return KeyboardAccessoryBar(
                          controller: _controller,
                          onDone: () => FocusScope.of(context).unfocus(),
                        );
                      }
                      return SafeArea(
                        top: false,
                        minimum:
                            const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                              AppSpacing.sm, AppSpacing.lg, 0),
                          child: ListenableBuilder(
                            listenable: _voice,
                            builder: (context, _) => _buildEntryArea(),
                          ),
                        ),
                      );
                    },
                  ),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRaceHeader(BuildContext context, bool live) {
    // RaceHeaderWidget only rebuilds when the current race changes.
    return ValueListenableBuilder<RaceRecord?>(
      valueListenable: _controller.currentRaceNotifier,
      builder: (context, currentRace, _) => CoachMark(
        id: 'race_header_tutorial',
        tutorialManager: _controller.tutorialManager,
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
          currentRace: currentRace,
          role: DeviceName.bibRecorder,
          compact: live,
          loading: _controller.loadingRace,
          onLoadRace: () => _controller.showLoadRaceSheet(context),
          onShowOtherRaces: () => _controller.showOtherRaces(context),
          onDeleteRace: () => _controller.deleteCurrentRace(),
          onShowRunners: currentRace != null
              ? () => _controller.showRunnersLoadedSheet(context)
              : null,
          onDownloadRace: currentRace != null
              ? () => _controller.downloadRace(context)
              : null,
          clearRecordsLabel: 'Clear Bibs',
          canClearRecords: () =>
              _controller.raceStopped && _controller.bibRecords.isNotEmpty,
          onClearRecords: () async {
            final confirmed = await DialogUtils.showConfirmationDialog(
              context,
              title: 'Clear Bibs',
              content: 'This removes every bib recorded for this race.',
              confirmText: 'Clear Bibs',
              cancelText: 'Cancel',
              destructive: true,
            );
            if (confirmed) await _controller.clearRecordedBibs();
          },
        ),
      ),
    );
  }

  /// The thumb area: the Keypad/Voice switch, then the big button for the
  /// mode chosen.
  Widget _buildEntryArea() {
    if (_controller.currentRace == null) return const SizedBox.shrink();
    final bool voiceOn = _voice.enabled;
    final Widget main;
    if (!voiceOn || (_controller.raceStopped && _controller.bibRecords.isNotEmpty)) {
      main = RaceControlsWidget(
        controller: _controller,
        onShare: _onShareBibNumbers,
      );
    } else if (_controller.raceStopped) {
      // Voice mode, not started: starting must not open the keypad.
      main = BigActionButton(
        key: const ValueKey('start_recording_button'),
        label: 'Start Recording',
        sublabel: 'Then hold the mic for each runner',
        icon: Icons.play_arrow_rounded,
        color: Colors.green.shade600,
        onPressed: () => _controller.raceStopped = false,
      );
    } else {
      main = VoiceEntryPanel(
        voice: _voice,
        describe: (bib) {
          final runner = _controller.getRunnerByBib(bib);
          if (runner == null) return null;
          return '${runner.name}, ${runner.teamAbbreviation}';
        },
        onUndo: () async {
          await _controller.removeLastBib();
          _voice.clearLastHeard();
        },
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: EntryModeToggle(voice: _voice)),
        const SizedBox(height: AppSpacing.sm),
        main,
      ],
    );
  }

  Future<void> _confirmStop() async {
    FocusScope.of(context).unfocus();
    final confirmed = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Stop Recording?',
      content: 'Stop once every runner has finished. You can resume if you '
          'stop too early.',
      confirmText: 'Stop',
      cancelText: 'Cancel',
      destructive: true,
    );
    if (confirmed && mounted) _controller.raceStopped = true;
  }

  Widget _buildRaceStatusWidget() {
    if (_controller.currentRace == null) return const SizedBox.shrink();
    final count = _controller.countNonEmptyBibNumbers();
    final String status;
    final Color statusColor;
    if (!_controller.raceStopped) {
      status = 'Recording';
      statusColor = AppColors.primaryColor;
    } else if (_controller.bibRecords.isNotEmpty) {
      status = 'Stopped';
      statusColor = Colors.green.shade700;
    } else {
      status = 'Ready';
      statusColor = AppColors.mediumColor;
    }
    return RaceDayStatusBar(
      status: status,
      color: statusColor,
      count: '$count ${count == 1 ? 'bib' : 'bibs'}',
      onStop: _controller.raceStopped ? null : _confirmStop,
    );
  }
}
