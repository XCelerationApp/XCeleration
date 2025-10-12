import 'package:flutter/material.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../core/utils/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/role_bar/models/role_enums.dart';
import '../../../shared/role_bar/role_bar.dart';
import '../controller/bib_number_controller.dart';
import '../widget/bib_list_widget.dart';
import '../widget/race_controls_widget.dart';
import '../widget/keyboard_accessory_bar.dart';
import '../../shared/widgets/race_header_widget.dart';
import '../../../core/components/race_components.dart' as core;

class BibNumberScreen extends StatefulWidget {
  const BibNumberScreen({super.key});

  @override
  State<BibNumberScreen> createState() => _BibNumberScreenState();
}

class _BibNumberScreenState extends State<BibNumberScreen> {
  late BibNumberController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BibNumberController(
      context: context,
    );
  }

  @override
  void dispose() {
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
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Column(children: [
                        RoleBar(
                          currentRole: Role.bibRecorder,
                          tutorialManager: _controller.tutorialManager,
                        ),
                        const SizedBox(height: 16.0),
                        RaceHeaderWidget(
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
                        const SizedBox(height: 8),
                        _buildRaceStatusWidget(),
                        const SizedBox(height: 16),
                        RaceControlsWidget(controller: _controller),
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
