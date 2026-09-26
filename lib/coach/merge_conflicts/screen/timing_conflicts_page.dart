import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/components/conflict_page_header.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/database/master_race.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../shared/models/timing_records/timing_chunk.dart';
import '../controller/merge_conflicts_controller.dart';
import 'merge_conflicts_screen.dart';

/// The timing conflicts as a full page, with the same Back bar and progress
/// as the bib conflicts before them. It used to be a sheet, so the two
/// halves of sorting out results looked and worked differently.
///
/// Expects a [MergeConflictsController] above it. Back keeps what was done
/// so far; the page closes itself once every conflict is resolved.
class TimingConflictsPage extends StatelessWidget {
  const TimingConflictsPage({
    super.key,
    required this.masterRace,
    required this.timingChunks,
    required this.raceRunners,
    required this.raceName,
    required this.total,
  });

  final MasterRace masterRace;
  final List<TimingChunk> timingChunks;
  final List<RaceRunner> raceRunners;
  final String raceName;

  /// How many conflicts there were when the page opened.
  final int total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ConflictNavBar(
              title: 'Timing Conflicts',
              raceName: raceName,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Selector<MergeConflictsController, int>(
              selector: (_, c) => c.openConflictCount,
              builder: (_, open, _) => ConflictProgress(
                resolved: (total - open).clamp(0, total),
                total: total,
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: MergeConflictsScreen(
                  masterRace: masterRace,
                  timingChunks: timingChunks,
                  raceRunners: raceRunners,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
