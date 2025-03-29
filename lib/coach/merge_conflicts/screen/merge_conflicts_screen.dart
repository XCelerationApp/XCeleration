import 'package:flutter/material.dart';
import 'package:xcelerate/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xcelerate/coach/merge_conflicts/widgets/save_button.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../model/timing_data.dart';
import '../../../core/components/instruction_card.dart';
import '../widgets/chunkList.dart';

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
  late MergeConflictsController _controller;

  @override
  void initState() {
    super.initState();
    _initializeState();
    
    // Add listener to rebuild UI when controller data changes
    _controller.addListener(_rebuildUi);
  }
  
  void _rebuildUi() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initializeState() {
    _controller = MergeConflictsController(
      raceId: widget.raceId,
      timingData: widget.timingData,
      runnerRecords: widget.runnerRecords,
    );
    _controller.setContext(context);
    _controller.initState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    _controller.updateRunnerInfo();
  }

  @override
  Widget build(BuildContext context) {
    // Set the controller's context
    _controller.setContext(context);
    
    return Scaffold(
      body: Container(
        color: AppColors.backgroundColor,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_controller.getFirstConflict()[0] == null)
                SaveButton(controller: _controller),
              Expanded(
                child: InstructionsAndList(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed
    _controller.dispose();
    super.dispose();
  }
}

class InstructionsAndList extends StatelessWidget {
  const InstructionsAndList({super.key, required this.controller});
  final MergeConflictsController controller;
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
              style: AppTypography.titleSemibold.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      children: [
        InstructionCard(
          title: 'Review Race Results',
          instructions: [
            InstructionItem(number: '1', text: 'Find the runners with the unknown times (orange)'),
            InstructionItem(number: '2', text: 'Update times as needed'),
            InstructionItem(number: '3', text: 'Save when all results are confirmed'),
          ],
        ),
        const SizedBox(height: 16),
        ChunkList(controller: controller),
      ],
    );
  }
}