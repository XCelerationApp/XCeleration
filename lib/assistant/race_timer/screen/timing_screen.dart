import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/timing_data.dart';
import '../model/timing_record.dart';
import '../../../shared/role_functions.dart';
import '../../../core/services/tutorial_manager.dart';
import '../../../utils/enums.dart';
import '../../../core/components/dialog_utils.dart';
import '../widgets/timer_display_widget.dart';
import '../widgets/race_controls_widget.dart';
import '../widgets/record_list_item.dart';
import '../widgets/race_info_header_widget.dart';
import '../widgets/bottom_controls_widget.dart';
import '../controller/timing_controller.dart';

class TimingScreen extends StatefulWidget {
  const TimingScreen({super.key});

  @override
  State<TimingScreen> createState() => _TimingScreenState();
}

class _TimingScreenState extends State<TimingScreen> with TickerProviderStateMixin {
  late TimingController _controller;
  late TabController _tabController;
  late final TutorialManager tutorialManager = TutorialManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _controller = TimingController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupTutorials();
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
    
    // Use the existing TimingData in the controller
    return ChangeNotifierProvider.value(
      value: _controller.timingData,
      child: Consumer<TimingData>(
        builder: (context, timingData, child) {
          return WillPopScope(
            onWillPop: () async {
              // Show confirmation dialog
              bool shouldPop = await DialogUtils.showConfirmationDialog(
                context,
                title: 'Leave Timing Screen?',
                content: 'All race times will be lost if you leave this screen. Do you want to continue?',
                confirmText: 'Continue',
                cancelText: 'Stay',
              );
              return shouldPop;
            },
            child: TutorialRoot(
              tutorialManager: tutorialManager,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildRoleBar(context, 'timer', tutorialManager),
                      const SizedBox(height: 8),
                      _buildRaceInfoHeader(),
                      const SizedBox(height: 8),
                      _buildTimerDisplay(),
                      _buildControlButtons(),
                      if (_controller.records.isNotEmpty) const SizedBox(height: 30),
                      Expanded(child: _buildRecordsList()),
                      if (_controller.timingData.startTime != null && _controller.records.isNotEmpty)
                        _buildBottomControls(),
                    ],
                  ),
                ),
              )
            ),
          );
        },
      ),
    );
  }

  Widget _buildRaceInfoHeader() {
    return RaceInfoHeaderWidget(
      startTime: _controller.timingData.startTime,
      endTime: _controller.timingData.endTime,
    );
  }

  Widget _buildTimerDisplay() {
    return TimerDisplayWidget(
      startTime: _controller.timingData.startTime,
      endTime: _controller.timingData.endTime,
    );
  }

  Widget _buildControlButtons() {
    return RaceControlsWidget(
      startTime: _controller.timingData.startTime,
      timingData: _controller.timingData,
      onStartRace: _controller.startRace,
      onStopRace: _controller.stopRace,
      onClearRaceTimes: _controller.clearRaceTimes,
      onLogButtonPress: _controller.handleLogButtonPress,
      hasRecords: _controller.records.isNotEmpty,
      isAudioPlayerReady: _controller.isAudioPlayerReady,
    );
  }

  Widget _buildRecordsList() {
    if (_controller.records.isEmpty) {
      return const Center(
        child: Text(
          'No race times yet',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _controller.scrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: _controller.records.length,
            separatorBuilder: (context, index) => const SizedBox(height: 1),
            itemBuilder: (context, index) {
              final record = _controller.records[index];
              if (record.type == RecordType.runnerTime) {
                return Dismissible(
                  key: ValueKey(record),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) => _controller.confirmRecordDismiss(record),
                  onDismissed: (direction) => _controller.onDismissRunnerTimeRecord(record, index),
                  child: _buildRunnerTimeRecord(record, index),
                );
              } else if (record.type == RecordType.confirmRunner) {
                return Dismissible(
                  key: ValueKey(record),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) => _controller.confirmRecordDismiss(record),
                  onDismissed: (direction) => _controller.onDismissConfirmationRecord(record, index),
                  child: _buildConfirmationRecord(record, index),
                );
              }
              // } else if (record.type == RecordType.missingRunner || record.type == RecordType.extraRunner) {
              //   return Dismissible(
              //     key: ValueKey(record),
              //     background: Container(
              //       color: Colors.red,
              //       alignment: Alignment.centerRight,
              //       padding: const EdgeInsets.only(right: 16.0),
              //       child: const Icon(
              //         Icons.delete,
              //         color: Colors.white,
              //       ),
              //     ),
              //     direction: DismissDirection.endToStart,
              //     confirmDismiss: (direction) => _controller.confirmRecordDismiss(record),
              //     onDismissed: (direction) => _controller.onDismissConflictRecord(record),
              //     child: _buildConflictRecord(record, index),
              //   );
              // }
              return const SizedBox.shrink();
            },
          )
        )
      ]
    );
  }

  Widget _buildRunnerTimeRecord(TimingRecord record, int index) {
    return RunnerTimeRecordItem(
      record: record,
      index: index,
      context: context,
    );
  }

  Widget _buildConfirmationRecord(TimingRecord record, int index) {
    return ConfirmationRecordItem(
      record: record,
      index: index,
      context: context,
    );
  }

  // Widget _buildConflictRecord(TimingRecord record, int index) {
  //   return ConflictRecordItem(
  //     record: record,
  //     index: index,
  //     context: context,
  //   );
  // }

  Widget _buildBottomControls() {
    return BottomControlsWidget(
      onConfirmRunnerNumber: _controller.confirmRunnerNumber,
      onMissingRunnerTime: () => _controller.missingRunnerTime(),
      onExtraRunnerTime: () => _controller.extraRunnerTime(),
      onUndoLastConflict: _controller.hasUndoableConflict() ? _controller.undoLastConflict : null,
      hasUndoableConflict: _controller.hasUndoableConflict(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
