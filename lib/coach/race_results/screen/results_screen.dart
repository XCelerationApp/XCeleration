import 'package:flutter/material.dart';
import 'package:xceleration/core/utils/logger.dart';
import 'package:xceleration/coach/share_race/controller/share_race_controller.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../widgets/share_button.dart';
import '../widgets/individual_results_widget.dart';
import '../widgets/team_results_widget.dart';

class ResultsScreen extends StatefulWidget {
  final MasterRace masterRace;

  const ResultsScreen({
    super.key,
    required this.masterRace,
  });

  @override
  State<ResultsScreen> createState() => ResultsScreenState();
}

class ResultsScreenState extends State<ResultsScreen> {
  RaceResultsData? _raceResultsData;
  bool _isLoading = true;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    loadRaceResults();
  }

  Future<void> loadRaceResults() async {
    // Prevent multiple loads
    if (_hasLoaded) {
      Logger.d('ResultsScreen: Already loaded, skipping');
      return;
    }

    Logger.d(
        'ResultsScreen: Starting to load race results for raceId: ${widget.masterRace.raceId}');
    try {
      _raceResultsData = await RaceResultsService.calculateCompleteRaceResults(
          widget.masterRace);
      Logger.d(
          'ResultsScreen: Race results loaded successfully, results count: ${_raceResultsData?.individualResults.length ?? 0}');
      _hasLoaded = true;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      Logger.e('ResultsScreen: Error loading race results: $e');
      Logger.e(
          'ResultsScreen: MasterRace instance: ${widget.masterRace.hashCode}');
      _hasLoaded = true; // Mark as loaded even on error to prevent retries
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundColor,
      child: Stack(
        children: [
          if (_isLoading) ...[
            const Center(
              child: CircularProgressIndicator(),
            ),
          ] else ...[
            Column(
              children: [
                if (_raceResultsData == null ||
                    _raceResultsData!.individualResults.isEmpty) ...[
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No results available',
                        style: AppTypography.titleSemibold,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Always show Team Results
                            TeamResultsWidget(
                              raceResultsData: _raceResultsData!,
                            ),
                            // Individual Results Widget
                            IndividualResultsWidget(
                              raceResultsData: _raceResultsData!,
                              initialVisibleCount: 5,
                            ),
                            // Add bottom padding for scrolling
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Share button
          if (_raceResultsData != null) ...[
            Positioned(
              bottom: 16,
              right: 16,
              child: ShareButton(onPressed: () {
                ShareRaceController.showShareRaceSheet(
                  context: context,
                  raceResultsData: _raceResultsData!,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
