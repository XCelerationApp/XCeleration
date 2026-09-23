import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../model/bib_conflict.dart';
import '../model/finish_order.dart';
import 'duplicate_bib_flow.dart';
import 'unknown_bib_card.dart';
import '../screen/resolve_bib_number_screen.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class BibConflictsOverview extends StatefulWidget {
  final MasterRace masterRace;
  final List<dynamic> raceRunners;
  final Function(List<RaceRunner>) onResolved;

  /// The Timer's finish time for each place it is not still unsure about,
  /// keyed by place. A place the Timer flagged is absent: which time belongs
  /// to which runner there has not been decided yet.
  final Map<int, String> timesByPlace;

  const BibConflictsOverview({
    super.key,
    required this.masterRace,
    required this.raceRunners,
    required this.onResolved,
    this.timesByPlace = const {},
  });

  @override
  State<BibConflictsOverview> createState() => _BibConflictsOverviewState();
}

class _BibConflictsOverviewState extends State<BibConflictsOverview> {
  late List<dynamic> _raceRunners;

  /// What is wrong with the finish order, or null while it is being worked out.
  List<BibConflict>? _conflicts;
  bool _resolved = false;
  bool _isRefreshing = false;
  // Set when looking up conflicts failed. Must not be mistaken for "no
  // conflicts": that would report the bibs resolved and drop them.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _raceRunners = List.from(widget.raceRunners);
    _refreshConflicts();
  }

  Future<void> _refreshConflicts() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _resolved = false;
    try {
      final conflicts = await detectBibConflicts(
        entries: _raceRunners,
        timesByPlace: widget.timesByPlace,
        lookupBib: widget.masterRace.getRaceRunnerByBib,
      );
      if (mounted) {
        setState(() {
          _loadFailed = false;
          _conflicts = conflicts;
        });
      }
    } catch (e) {
      Logger.e('[BibConflictsOverview._refreshConflicts] $e');
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Writes the runners the coach settled on into the finish order.
  Future<void> _applyResolved(Map<int, RaceRunner> settled) async {
    setState(() => _raceRunners = applyResolvedFinishes(_raceRunners, settled));
    await _refreshConflicts();
  }

  @override
  void didUpdateWidget(BibConflictsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.raceRunners != oldWidget.raceRunners) {
      setState(() {
        _raceRunners = List.from(widget.raceRunners);
      });
      _refreshConflicts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not check the bib numbers.'),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _refreshConflicts,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final conflicts = _conflicts;
    if (conflicts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conflicts.isEmpty) {
      // All conflicts resolved - call onResolved callback exactly once per resolution event.
      if (!_resolved) {
        _resolved = true;
        final resolvedRunners = _raceRunners.whereType<RaceRunner>().toList();
        // Use addPostFrameCallback to ensure the widget tree is updated before calling the callback
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onResolved(resolvedRunners);
        });
      }

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(Colors.green, 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Unfound Bib Numbers',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 12),
            Text(
              'All runners have valid bib numbers',
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${conflicts.length} Unfound Bib Numbers',
                style: AppTypography.headerSemibold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a bib number to resolve',
                style: AppTypography.bodyRegular.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
        Container(
          height: 280,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: conflicts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildConflictTile(context, conflicts[index]),
          ),
        ),
      ],
    );
  }

  /// Replaces the unresolved entry behind [raceRunner]'s tile with
  /// [replacement], or removes it when [replacement] is null.
  /// Opens the right resolution flow for [conflict].
  Future<void> _resolve(BuildContext context, BibConflict conflict) async {
    switch (conflict) {
      case DuplicateBibConflict():
        await _resolveDuplicate(context, conflict);
      case UnknownBibConflict():
        await _resolveUnknown(context, conflict);
    }
  }

  /// A bib recorded at more than one finish: which one is the runner's, then
  /// who each of the others was.
  Future<void> _resolveDuplicate(
      BuildContext context, DuplicateBibConflict conflict) async {
    final settled = await sheet(
      context: context,
      title: 'Bib #${conflict.bibNumber} recorded twice',
      body: DuplicateBibFlow(
        conflict: conflict,
        onComplete: (resolved) => Navigator.pop(context, resolved),
        buildAssignment: (context, leftover, onAssigned) => SizedBox(
          height: 420,
          child: ResolveBibNumberScreen(
            raceRunner: _placeholderFor(conflict.bibNumber),
            raceId: widget.masterRace.raceId,
            raceRunners: _raceRunners.whereType<RaceRunner>().toList(),
            onComplete: onAssigned,
            // The runner whose bib it is has already been settled in step one.
            onAssignOriginalRaceRunner: (_) async {},
          ),
        ),
      ),
    );
    if (settled is Map<int, RaceRunner>) await _applyResolved(settled);
  }

  /// A bib no runner has: assign it to someone, or create them.
  ///
  /// Somebody crossed the line here either way — the Bib Recorder taps once
  /// per finisher — so the finish itself is never in question, only whose it
  /// is. A time the Timer missed or added over is a timing conflict, resolved
  /// after these.
  Future<void> _resolveUnknown(
      BuildContext context, UnknownBibConflict conflict) async {
    final place = conflict.occurrence.place;
    final resolved = await sheet(
      context: context,
      title: 'Resolve Bib #${conflict.bibNumber}',
      body: UnknownBibCard(
        conflict: conflict,
        buildAssignment: (context) => SizedBox(
          height: 420,
          child: ResolveBibNumberScreen(
            raceRunner: _placeholderFor(conflict.bibNumber),
            raceId: widget.masterRace.raceId,
            raceRunners: _raceRunners.whereType<RaceRunner>().toList(),
            onComplete: (runner) => Navigator.pop(context, runner),
            onAssignOriginalRaceRunner: (_) async {},
          ),
        ),
      ),
    );
    if (resolved is RaceRunner) await _applyResolved({place: resolved});
  }

  /// Stands in for the runner behind a bib that has not been identified yet.
  RaceRunner _placeholderFor(String bibNumber) => RaceRunner(
        raceId: widget.masterRace.raceId,
        runner: Runner(bibNumber: bibNumber),
        team: Team(),
      );

  Widget _buildConflictTile(BuildContext context, BibConflict conflict) {
    final isDuplicate = conflict is DuplicateBibConflict;
    final places = switch (conflict) {
      DuplicateBibConflict(:final occurrences) =>
        occurrences.map((o) => o.place).toList(),
      UnknownBibConflict(:final occurrence) => [occurrence.place],
    };
    final time = switch (conflict) {
      DuplicateBibConflict() => null,
      UnknownBibConflict(:final occurrence) => occurrence.time,
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ColorUtils.withOpacity(AppColors.primaryColor, 0.15),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _resolve(context, conflict),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${places.first}.',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ),
              Text(
                '#${conflict.bibNumber}',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDuplicate
                          ? 'Duplicate Bib Number'
                          : 'Bib number not found',
                      style: AppTypography.bodyRegular.copyWith(
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDuplicate
                          ? 'Recorded at ${places.join(', ')}'
                          : (time ?? 'Time not settled yet'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.mediumColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.withOpacity(Colors.black, 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
