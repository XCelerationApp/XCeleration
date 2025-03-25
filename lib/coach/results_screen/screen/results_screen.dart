import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:xcelerate/coach/share_race/controller/share_race_controller.dart';
import '../../../utils/csv_utils.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../utils/database_helper.dart';
import '../widgets/share_button.dart';
import '../widgets/individual_results_widget.dart';
import '../widgets/head_to_head_results.dart';
import '../widgets/overall_team_results.dart';
import '../model/results_record.dart';
import '../model/team_record.dart';

class ResultsScreen extends StatefulWidget {
  final int raceId;

  const ResultsScreen({
    super.key,
    required this.raceId,
  });

  @override
  State<ResultsScreen> createState() => ResultsScreenState();
}

class ResultsScreenState extends State<ResultsScreen> {
  bool _isHeadToHead = false;
  bool _isLoading = true;
  List<ResultsRecord> _individualResults = [];
  List<TeamRecord> _overallTeamResults = [];
  List<TeamRecord> _individualTeamResults = [];
  List<List<TeamRecord>> _headToHeadTeamResults = [];

  @override
  void initState() {
    super.initState();
    _calculateResults();
  }

  Future<void> _calculateResults() async {
    final List<ResultsRecord> results = await DatabaseHelper.instance.getRaceResults(widget.raceId);
    updateResultsPlaces(results);
    setState(() {
      _individualResults = List.from(results);
    });

    final List<TeamRecord> teamResults = _calculateTeams(results);
    setState(() {
      _overallTeamResults = List.from(teamResults);
      sortAndPlaceTeams(_overallTeamResults);
    });

    final List<TeamRecord> individualTeamResults = List.from(teamResults);
    for (var team in individualTeamResults) {
      updateResultsPlaces(team.runners);
    }

    setState(() {
      _individualTeamResults = individualTeamResults;
    });

    final List<List<TeamRecord>> headToHeadResults = [];
    for (var i = 0; i < teamResults.length; i++) {
      for (var j = i + 1; j < teamResults.length; j++) {
        final teamA = TeamRecord.from(teamResults[i]);
        final teamB = TeamRecord.from(teamResults[j]);
        final filteredRunners = [...teamA.runners, ...teamB.runners];
        filteredRunners.sort((a, b) => b.finishTime.compareTo(a.finishTime));
        updateResultsPlaces(filteredRunners);
        teamA.updateStats();
        teamB.updateStats();
        final matchup = [teamA, teamB];
        sortAndPlaceTeams(matchup);
        headToHeadResults.add(matchup);
      }
    }

    setState(() {
      _headToHeadTeamResults = headToHeadResults;
      _isLoading = false;
    });
  }

  List<TeamRecord> _calculateTeams(List<ResultsRecord> allResults) {
    final List<TeamRecord> teams = [];
    for (var team in groupBy(allResults, (result) => result.school).entries) {
      final teamRecord = TeamRecord(
        school: team.key,
        runners: team.value,
      );
      teams.add(teamRecord);
    }
    return teams;
  }

  void updateResultsPlaces(List<ResultsRecord> results) {
    for (int i = 0; i < results.length; i++) {
      results[i].place = i + 1;
    }
  }

  void sortAndPlaceTeams(List<TeamRecord> teams) {
    teams.sort((a, b) => b.score - a.score);
    for (int i = 0; i < teams.length; i++) {
      teams[i].place = i + 1;
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
                if (_individualResults.isEmpty) ...[
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
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'View:',
                                          style: AppTypography.bodyRegular,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.backgroundColor,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _isHeadToHead = false;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: !_isHeadToHead
                                                            ? AppColors.primaryColor
                                                            : Colors.transparent,
                                                        borderRadius:
                                                            const BorderRadius.horizontal(left: Radius.circular(8)),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'Overall',
                                                          style: AppTypography.bodySemibold.copyWith(
                                                            color: !_isHeadToHead ? Colors.white : Colors.black54,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _isHeadToHead = true;
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: _isHeadToHead
                                                            ? AppColors.primaryColor
                                                            : Colors.transparent,
                                                        borderRadius:
                                                            const BorderRadius.horizontal(right: Radius.circular(8)),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          'Head to Head',
                                                          style: AppTypography.bodySemibold.copyWith(
                                                            color: _isHeadToHead ? Colors.white : Colors.black54,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_isHeadToHead) ...[
                                  OverallTeamResultsWidget(
                                    overallTeamResults: _overallTeamResults,
                                  ),
                                ] else ...[
                                  HeadToHeadResults(
                                    headToHeadTeamResults: _headToHeadTeamResults,
                                  ),
                                ],
                                const Divider(),
                                // Individual Results Section
                                IndividualResultsWidget(
                                  individualResults: _individualResults,
                                ),
                                // Add bottom padding for scrolling
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          // Share button
          Positioned(
            bottom: 16,
            right: 16,
            child: ShareButton(onPressed: () {
              ShareRaceController.showShareRaceSheet(
                context: context,
                headToHeadTeamResults: _headToHeadTeamResults,
                overallTeamResults: _overallTeamResults,
                individualResults: _individualResults,
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> downloadCsv(List<Map<String, dynamic>> teamResults, List<Map<String, dynamic>> individualResults) async {
    try {
      // Generate CSV content
      final csvContent = CsvUtils.generateCsvContent(
        isHeadToHead: _isHeadToHead,
        teamResults: teamResults,
        individualResults: individualResults
      );

      // Define the filename
      final filename = 'race_results.csv';

      // Save CSV file
      final filepath = await CsvUtils.saveCsvWithFileSaver(filename, csvContent);
      if (!mounted) return;
      if (filepath != '') {
        DialogUtils.showSuccessDialog(context, message: 'CSV saved at $filepath');
      }
      else {
        DialogUtils.showErrorDialog(context, message: 'No location selected for download');
      }

    } catch (e) {
      DialogUtils.showErrorDialog(context, message: 'Failed to download CSV: $e');
    }
  }
}
