import 'package:flutter/material.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
import 'package:xceleration/coach/merge_conflicts/widgets/save_button.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/timing_records/timing_chunk.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/instruction_card.dart';
import '../widgets/chunk_list.dart';
import 'package:provider/provider.dart';


class MergeConflictsScreen extends StatefulWidget {
  final MasterRace masterRace;
  final List<TimingChunk> timingChunks;
  final List<RaceRunner> raceRunners;

  const MergeConflictsScreen({
    super.key,
    required this.masterRace,
    required this.timingChunks,
    required this.raceRunners,
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
    controller.setContext(context);
    controller.initState();
    controller.addListener(_rebuildUi);
  }

  void _rebuildUi() {
    if (mounted) {
      setState(() {});
    }
  }



  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MergeConflictsController>(context);
    controller.setContext(context);
    return Container(
      color: AppColors.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            if (controller.hasConflicts)
              SaveButton(controller: controller),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  InstructionsAndList(
                    controller: controller,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
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
  });
  final MergeConflictsController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.timingChunks.isEmpty) {
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
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        children: [

          // Instructions card
          InstructionCard(
            title: 'Review Race Results',
            instructions: [
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
          ChunkList(controller: controller),
        ],
      ),
    );
  }
}
