import 'package:flutter/material.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/widgets/save_button.dart';
import 'package:xceleration/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../model/timing_data.dart';
import '../../../core/components/instruction_card.dart';
import '../widgets/chunk_list.dart';
import 'package:provider/provider.dart';
import '../demo/complexity_comparison.dart';
import '../widgets/mock_data_selector.dart';
import '../widgets/simple_conflict_widget.dart';

class MergeConflictsScreen extends StatefulWidget {
  final int raceId;
  final TimingData timingData;
  final List<RunnerRecord> runnerRecords;

  const MergeConflictsScreen({
    super.key,
    required this.raceId,
    required this.timingData,
    required this.runnerRecords,
  });

  @override
  State<MergeConflictsScreen> createState() => _MergeConflictsScreenState();
}

class _MergeConflictsScreenState extends State<MergeConflictsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeState());
  }

  void _initializeState() {
    final controller =
        Provider.of<MergeConflictsController>(context, listen: false);
    final controller =
        Provider.of<MergeConflictsController>(context, listen: false);
    controller.setContext(context);
    controller.initState();
    controller.addListener(_rebuildUi);
  }

  void _rebuildUi() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showMockDataDialog(
      BuildContext context, MergeConflictsController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: MockDataSelector(controller: controller),
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller =
        Provider.of<MergeConflictsController>(context, listen: false);
    final controller =
        Provider.of<MergeConflictsController>(context, listen: false);
    controller.updateRunnerInfo();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MergeConflictsController>(context);
    controller.setContext(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          '${controller.currentModeString} Mode',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: controller.useSimpleMode ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                controller.toggleMode();
                setState(() {}); // Rebuild to show the new mode
              },
              icon: Icon(
                controller.useSimpleMode ? Icons.toggle_on : Icons.toggle_off,
                color: Colors.white,
                size: 28,
              ),
              label: Text(
                controller.currentModeString,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: AppColors.backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              if (controller.getFirstConflict()[0] == null)
                SaveButton(controller: controller),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    InstructionsAndList(
                      controller: controller,
                      onShowMockData: () =>
                          _showMockDataDialog(context, controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick mode toggle FAB
          FloatingActionButton(
            heroTag: 'toggle_mode',
            onPressed: () {
              controller.toggleMode();
            },
            backgroundColor:
                controller.useSimpleMode ? Colors.green : Colors.blue,
            child: Icon(
              controller.useSimpleMode ? Icons.lightbulb : Icons.settings,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'mock_data',
            onPressed: () {
              _showMockDataDialog(context, controller);
            },
            backgroundColor: Colors.orange,
            child: const Icon(Icons.science),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'compare_modes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ComplexityComparisonDemo(controller: controller),
                ),
              );
            },
            icon: const Icon(Icons.compare),
            label: const Text('Compare Modes'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    final controller =
        Provider.of<MergeConflictsController>(context, listen: false);
    final controller =
        Provider.of<MergeConflictsController>(context, listen: false);
    controller.removeListener(_rebuildUi);
    controller.dispose();
    super.dispose();
  }
}

class InstructionsAndList extends StatelessWidget {
  const InstructionsAndList({
    super.key,
    required this.controller,
    required this.onShowMockData,
  });
  final MergeConflictsController controller;
  final VoidCallback onShowMockData;
  @override
  Widget build(BuildContext context) {
    if (controller.timingData.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No race results to review',
              style:
                  AppTypography.titleSemibold.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Load mock data to test conflict resolution',
              style: AppTypography.bodyMedium.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onShowMockData,
              icon: const Icon(Icons.science),
              label: const Text('Load Mock Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode indicator card
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: controller.useSimpleMode
                  ? Colors.green.shade50
                  : Colors.blue.shade50,
              border: Border.all(
                color: controller.useSimpleMode ? Colors.green : Colors.blue,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  controller.useSimpleMode ? Icons.lightbulb : Icons.settings,
                  color: controller.useSimpleMode ? Colors.green : Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${controller.currentModeString} Mode Active',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: controller.useSimpleMode
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.modeDescription,
                        style: TextStyle(
                          color: controller.useSimpleMode
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Instructions card
          InstructionCard(
            title: controller.useSimpleMode
                ? 'Simple Conflict Resolution'
                : 'Review Race Results',
            instructions: controller.useSimpleMode
                ? [
                    InstructionItem(
                        number: '1',
                        text: 'View conflicts in a simplified list format'),
                    InstructionItem(
                        number: '2',
                        text: 'Resolve conflicts with direct input'),
                    InstructionItem(
                        number: '3', text: 'Changes are applied immediately'),
                  ]
                : [
                    InstructionItem(
                        number: '1',
                        text:
                            'Find the runners with the unknown times (orange)'),
                    InstructionItem(
                        number: '2', text: 'Update times as needed'),
                    InstructionItem(
                        number: '3',
                        text: 'Save when all results are confirmed'),
                  ],
          ),
          const SizedBox(height: 16),

          // Content based on mode
          controller.useSimpleMode
              ? SimpleConflictWidget(controller: controller)
              : ChunkList(controller: controller),
        ],
      ),
    );
  }
}
