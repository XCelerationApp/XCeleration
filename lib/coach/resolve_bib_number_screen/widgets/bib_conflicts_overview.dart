import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../screen/resolve_bib_number_screen.dart';
import 'package:xceleration/core/utils/color_utils.dart';

class BibConflictsOverview extends StatefulWidget {
  final List<RaceRunner> raceRunners;
  final Function(List<RaceRunner>) onConflictSelected;
  final MasterRace masterRace;

  const BibConflictsOverview({
    super.key,
    required this.raceRunners,
    required this.onConflictSelected,
    required this.masterRace,
  });

  @override
  State<BibConflictsOverview> createState() => _BibConflictsOverviewState();
}

class _BibConflictsOverviewState extends State<BibConflictsOverview> {
  late List<RaceRunner> _raceRunners;
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
    final allRaceRunners = await widget.masterRace.raceRunners;
    final allRaceRunnerBibNumbers = allRaceRunners.map((rr) => rr.runner.bibNumber!).toList();

    final unknownRaceRunnersFutures = _raceRunners.map((raceRunner) async {
      final bibNumber = raceRunner.runner.bibNumber;
      if (bibNumber == null || !allRaceRunnerBibNumbers.contains(bibNumber)) {
        return raceRunner;
      }
      return null;
    }).toList();

    final unknownRaceRunnersResults = await Future.wait(unknownRaceRunnersFutures);
    _unknownRaceRunners = unknownRaceRunnersResults.whereType<RaceRunner>().toList();

    final raceRunnersCopy = List.from(_raceRunners);

    final duplicateRaceRunnersFutures = allRaceRunners.map((raceRunner) async {
      if (!raceRunnersCopy.remove(raceRunner)) {
        return raceRunner;
      }
      return null;
    }).toList();

    final duplicateRaceRunnersResults = await Future.wait(duplicateRaceRunnersFutures);
    _duplicateRaceRunners = duplicateRaceRunnersResults.whereType<RaceRunner>().toList();

    _errorRaceRunners = [..._unknownRaceRunners!, ..._duplicateRaceRunners!];
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
              raceRunners: _raceRunners,
              onComplete: (record) => Navigator.pop(context, record),
            ),
          );

          if (updatedRaceRunner != null) {
            setState(() {
              _raceRunners.remove(raceRunner);
              _raceRunners.insert(index, updatedRaceRunner);
              _unknownRaceRunners!.remove(raceRunner);
              _duplicateRaceRunners!.remove(raceRunner);
              _errorRaceRunners!.remove(raceRunner);
            });
            if (_errorRaceRunners!.isEmpty) {
              widget.onConflictSelected(_raceRunners);
            }
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
                      _duplicateRaceRunners!.contains(raceRunner) ? 'Duplicate Bib Number' : 'Bib number not found',
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
