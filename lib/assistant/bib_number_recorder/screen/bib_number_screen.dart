import 'package:flutter/material.dart';
import '../../../core/components/dialog_utils.dart';
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
import '../widget/bib_list_widget.dart';
import '../widget/race_controls_widget.dart';
import '../widget/keyboard_accessory_bar.dart';
import '../widget/runners_loaded_sheet.dart';
import '../../shared/widgets/race_header_widget.dart';
import '../../../core/components/race_components.dart' as core;
import '../../../core/components/coach_mark.dart';

class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key, required this.controller});

  final BibNumberController controller;

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  late BibNumberController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      InstructionsBanner.showInstructionsSheet(context, Role.bibRecorder).then((_) {
        if (mounted) _controller.setupTutorials();
      });
    });
  }

  void _onControllerChanged() {
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
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Scaffold(
                resizeToAvoidBottomInset: true,
                body: Column(children: [
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
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: [
                        CoachMark(
                          id: 'race_header_tutorial',
                          tutorialManager: _controller.tutorialManager,
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
                            role: DeviceName.bibRecorder,
                            onLoadRace: () =>
                                _controller.showLoadRaceSheet(context),
                            onShowOtherRaces: () =>
                                _controller.showOtherRaces(context),
                            onDeleteRace: () => _controller.deleteCurrentRace(),
                            onShowRunners: _controller.currentRace != null
                                ? () =>
                                    _controller.showRunnersLoadedSheet(context)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRaceStatusWidget(),
                        const SizedBox(height: 16),
                        RaceControlsWidget(
                          controller: _controller,
                          onShare: _onShareBibNumbers,
                        ),
                        const SizedBox(height: 8),
                      ])),

                  // Bib input list section - moved outside the inner Column
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: BibListWidget(
                        controller: _controller,
                      ),
                    ),
                  ),

                  // Keyboard accessory bar for mobile devices
                  KeyboardAccessoryBar(
                    controller: _controller,
                    onDone: () => FocusScope.of(context).unfocus(),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRaceStatusWidget() {
    String status;
    Color statusColor;

    if (_controller.currentRace == null) {
      status = 'No Race Loaded';
      statusColor = Colors.grey;
    } else if (_controller.raceStopped) {
      if (_controller.bibRecords.isNotEmpty) {
        status = 'Completed';
        statusColor = Colors.green[700]!;
      } else {
        status = 'Ready';
        statusColor = Colors.black54;
      }
    } else {
      status = 'In Progress';
      statusColor = AppColors.primaryColor;
    }

    return core.RaceStatusHeaderWidget(
      status: status,
      statusColor: statusColor,
      recordCount: _controller.bibRecords.length,
      recordLabel: 'Bibs',
    );
  }
}
