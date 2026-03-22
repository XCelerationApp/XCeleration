import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
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
  Set<RaceRunner>? _duplicateRaceRunners;
  List<int>? _duplicateBibNumberPlaces;
  List<RaceRunner>? _errorRaceRunners;
  bool _resolved = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _raceRunners = List.from(widget.raceRunners);
    Logger.d('Loading race runners');

    _getErrorRaceRunners();
  }

  Future<void> _getErrorRaceRunners() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _resolved = false;
    Logger.d('Race Runners: $_raceRunners');
    try {
      final unknownRunners = <RaceRunner>[];
      final duplicateRunners = <RaceRunner>{};
      final duplicateBibNumberPlaces = <int>[];

      // Find duplicate bibs within the resolved runners
      final seenBibs = <String>{};
      for (int i = 0; i < _raceRunners.length; i++) {
        final item = _raceRunners[i];
        if (item is RaceRunner) {
          final bibNumber = item.runner.bibNumber;
          if (bibNumber == null) continue;
          if (seenBibs.contains(bibNumber)) {
            duplicateRunners.add(item);
            duplicateBibNumberPlaces.add(i);
          } else {
            seenBibs.add(bibNumber);
          }
        }
      }

      // Collect runners for bib numbers that need resolution.
      // Fire all DB lookups concurrently rather than awaiting each one in turn.
      final futures = <Future<RaceRunner?>>[];
      final futureIndices = <int>[];

      for (int i = 0; i < _raceRunners.length; i++) {
        final bibNumber = _raceRunners[i];
        if (bibNumber is int) {
          if (seenBibs.contains(bibNumber.toString())) {
            futures.add(widget.masterRace.getRaceRunnerByBib(bibNumber.toString()));
            futureIndices.add(i);
          } else {
            // Create a placeholder runner for display purposes
            unknownRunners.add(RaceRunner(
              raceId: widget.masterRace.raceId,
              runner: Runner(bibNumber: bibNumber.toString()),
              team: Team(),
            ));
          }
        }
      }

      final resolved = await Future.wait(futures);
      for (int j = 0; j < resolved.length; j++) {
        final runner = resolved[j];
        if (runner == null) {
          // DB lookup returned nothing — treat as unknown
          unknownRunners.add(RaceRunner(
            raceId: widget.masterRace.raceId,
            runner: Runner(bibNumber: _raceRunners[futureIndices[j]].toString()),
            team: Team(),
          ));
        } else {
          duplicateRunners.add(runner);
          duplicateBibNumberPlaces.add(futureIndices[j]);
        }
      }

      if (mounted) {
        setState(() {
          _unknownRaceRunners = unknownRunners;
          _duplicateRaceRunners = duplicateRunners;
          _duplicateBibNumberPlaces = duplicateBibNumberPlaces;
          _errorRaceRunners = [...unknownRunners, ...duplicateRunners];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _unknownRaceRunners = [];
          _duplicateRaceRunners = {};
          _duplicateBibNumberPlaces = [];
          _errorRaceRunners = [];
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void didUpdateWidget(BibConflictsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.raceRunners != oldWidget.raceRunners) {
      setState(() {
        _raceRunners = List.from(widget.raceRunners);
      });
      _getErrorRaceRunners();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unknownRaceRunners == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final errorRaceRunners = _errorRaceRunners!;

    if (errorRaceRunners.isEmpty) {
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
              onAssignOriginalRaceRunner: (record) async {
                int position = 0;
                for (final item in _duplicateRaceRunners!) {
                  if (item == record) {
                    break;
                  }
                  if (item.runner.bibNumber == record.runner.bibNumber) {
                    position++;
                  }
                }
                setState(() {
                  for (int i = 0; i < _raceRunners.length; i++) {
                    final item = _raceRunners[i];
                    if (item is RaceRunner &&
                        item.runner.bibNumber == record.runner.bibNumber) {
                      // Convert other RaceRunners with same bib to unresolved integers
                      final bib = item.runner.bibNumber;
                      if (bib != null) _raceRunners[i] = int.parse(bib);
                    } else if (item is int &&
                        item.toString() == record.runner.bibNumber) {
                      if (position == 0) {
                        _raceRunners[i] = record;
                      } else {
                        position--;
                      }
                    }
                  }
                });
                await _getErrorRaceRunners();
              },
            ),
          );

          if (updatedRaceRunner != null) {
            // Compute the index outside setState so the async refresh runs after the sync state update.
            int index = -1;
            if (_duplicateRaceRunners!.contains(raceRunner)) {
              index = _raceRunners.indexWhere(
                  (r) => r is int && r.toString() == raceRunner.runner.bibNumber);
            } else {
              final conflictBib =
                  int.tryParse(raceRunner.runner.bibNumber ?? '') ??
                      raceRunner.runner.bibNumber;
              index = _raceRunners.indexWhere((r) => r == conflictBib);
            }

            if (index != -1) {
              setState(() => _raceRunners[index] = updatedRaceRunner);
              await _getErrorRaceRunners();
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (_duplicateRaceRunners!.contains(raceRunner)) ...[
                Text(
                  '${_duplicateBibNumberPlaces![index]}.',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '#${raceRunner.runner.bibNumber}',
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
                    if (_duplicateRaceRunners!.contains(raceRunner)) ...[
                      Text(
                        '${raceRunner.runner.name ?? ''}.',
                        style: AppTypography.bodyRegular.copyWith(
                          color: AppColors.mediumColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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
