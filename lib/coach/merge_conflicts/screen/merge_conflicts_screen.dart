import 'package:flutter/material.dart';
import 'package:xceleration/coach/merge_conflicts/controller/merge_conflicts_controller.dart';
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
  late MergeConflictsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Provider.of<MergeConflictsController>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeState());
  }

  void _initializeState() {
    _controller.onReadyToClose = () {
      if (mounted) Navigator.of(context).pop(null);
    };
    _controller.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [InstructionsAndList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Don't dispose controller - Provider handles it
    super.dispose();
  }
}

class InstructionsAndList extends StatelessWidget {
  const InstructionsAndList({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<MergeConflictsController, bool>(
      selector: (_, c) => c.timingChunks.isEmpty,
      builder: (context, isEmpty, _) {
        if (isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No race results to review',
                  style: AppTypography.titleSemibold
                      .copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            children: [
              InstructionCard(
                title: 'Review Race Results',
                instructions: [
                  InstructionItem(
                      number: '1',
                      text: 'Find the runners with the unknown times (orange)'),
                  InstructionItem(number: '2', text: 'Update times as needed'),
                  InstructionItem(
                      number: '3', text: 'Save when all results are confirmed'),
                ],
              ),
              SizedBox(height: 16),
              ChunkList(),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
