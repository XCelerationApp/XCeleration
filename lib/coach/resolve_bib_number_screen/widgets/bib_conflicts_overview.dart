import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../screen/resolve_bib_number_screen.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class BibConflictsOverview extends StatefulWidget {
  final MasterRace masterRace;
  final List<dynamic> raceRunners;
  final Function(List<RaceRunner>) onResolved;

  const BibConflictsOverview({
    super.key,
    required this.masterRace,
    required this.raceRunners,
    required this.onResolved,
  });

  @override
  State<BibConflictsOverview> createState() => _BibConflictsOverviewState();
}

class _BibConflictsOverviewState extends State<BibConflictsOverview> {
  late List<dynamic> _raceRunners;
  List<RaceRunner>? _unknownRaceRunners;
  List<RaceRunner>? _duplicateRaceRunners;
  List<RaceRunner>? _errorRaceRunners;

  @override
  void initState() {
    super.initState();
    _raceRunners = widget.raceRunners;

    _getErrorRaceRunners();
  }

  Future<void> _getErrorRaceRunners() async {
    try {
      final unknownRunners = <RaceRunner>[];
      final duplicateRunners = <RaceRunner>[];

      // Collect runners for bib numbers that need resolution
      for (final item in _raceRunners) {
        if (item is int) {
          // Create a placeholder runner for display purposes
          final placeholderRunner = RaceRunner(
            raceId: widget.masterRace.raceId,
            runner: Runner(bibNumber: item.toString()),
            team: Team(),
          );
          unknownRunners.add(placeholderRunner);
        }
      }

      // Find duplicate bibs within the resolved runners
      final seenBibs = <String>{};
      for (final item in _raceRunners) {
        if (item is RaceRunner) {
          final bibNumber = item.runner.bibNumber!;
          if (seenBibs.contains(bibNumber)) {
            duplicateRunners.add(item);
          } else {
            seenBibs.add(bibNumber);
          }
        }
      }

      if (mounted) {
        setState(() {
          _unknownRaceRunners = unknownRunners;
          _duplicateRaceRunners = duplicateRunners;
          _errorRaceRunners = [...unknownRunners, ...duplicateRunners];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unknownRaceRunners = [];
          _duplicateRaceRunners = [];
          _errorRaceRunners = [];
        });
      }
    }
  }

  @override
  void didUpdateWidget(BibConflictsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.raceRunners != oldWidget.raceRunners) {
      setState(() {
        _raceRunners = widget.raceRunners;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unknownRaceRunners == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final errorRaceRunners = _errorRaceRunners!;

    if (errorRaceRunners.isEmpty) {
      // All conflicts resolved - call onResolved callback and close the sheet
      final resolvedRunners = _raceRunners.whereType<RaceRunner>().toList();

      // Use addPostFrameCallback to ensure the widget tree is updated before calling the callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onResolved(resolvedRunners);
      });

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
                '${errorRaceRunners.length} Unfound Bib Numbers',
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
            itemCount: errorRaceRunners.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildConflictTile(context, errorRaceRunners[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildConflictTile(
      BuildContext context, RaceRunner raceRunner, int index) {
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
        onTap: () async {
          final updatedRaceRunner = await sheet(
            context: context,
            title: 'Resolve Bib #${raceRunner.runner.bibNumber} Conflict',
            body: ResolveBibNumberScreen(
              raceRunner: raceRunner,
              raceId: widget.masterRace.raceId,
              raceRunners: _raceRunners.whereType<RaceRunner>().toList(),
              onComplete: (record) => Navigator.pop(context, record),
            ),
          );

          if (updatedRaceRunner != null) {
            setState(() {
              // Handle both unknown bib conflicts (integers) and duplicate bib conflicts (RaceRunner objects)
              int index = -1;

              if (_duplicateRaceRunners!.contains(raceRunner)) {
                // This is a duplicate bib conflict - find the RaceRunner object in the list
                // For duplicates, find any RaceRunner with the same bib number (since we're replacing the entire duplicate)
                // Note: This finds the first RaceRunner with this bib number - there may be multiple duplicates
                index = _raceRunners.indexWhere((r) =>
                    r is RaceRunner &&
                    r.runner.bibNumber == raceRunner.runner.bibNumber);
              } else {
                // This is an unknown bib conflict - find the integer in the list
                final conflictBib =
                    int.tryParse(raceRunner.runner.bibNumber!) ??
                        raceRunner.runner.bibNumber;
                index = _raceRunners.indexWhere((r) => r == conflictBib);
              }

              if (index != -1) {
                _raceRunners[index] = updatedRaceRunner;
                _getErrorRaceRunners();
              } else {}
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Hero(
                tag: 'bib-${raceRunner.runner.bibNumber}',
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ColorUtils.withOpacity(AppColors.primaryColor, 0.12),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [
                      BoxShadow(
                        color:
                            ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '#${raceRunner.runner.bibNumber}',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _duplicateRaceRunners!.contains(raceRunner)
                          ? 'Duplicate Bib Number'
                          : 'Bib number not found',
                      style: AppTypography.bodyRegular.copyWith(
                        letterSpacing: 0.1,
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
