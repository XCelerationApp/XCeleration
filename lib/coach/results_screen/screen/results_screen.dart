import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:xcelerate/assistant/race_timer/timing_screen/model/timing_record.dart' show TimingRecord;
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../utils/time_formatter.dart';
import '../../../utils/csv_utils.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../utils/sheet_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../utils/database_helper.dart';
import '../../share_sheet_screen/screen/share_sheet_screen.dart';

class ResultsScreen extends StatefulWidget {
  final int raceId;
  final VoidCallback? onBack;

  const ResultsScreen({
    super.key,
    required this.raceId,
    this.onBack,
  });

  @override
  State<ResultsScreen> createState() => ResultsScreenState();
}

class ResultsScreenState extends State<ResultsScreen> {
  bool _isHeadToHead = false;
  List<TimingRecord> _results = [];
  List<RunnerRecord> _runners = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final List<TimingRecord> results = await DatabaseHelper.instance.getRaceResults(widget.raceId);
    final List<RunnerRecord> runners = await DatabaseHelper.instance.getRaceRunners(widget.raceId);
    setState(() {
      _results = results;
      _runners = runners;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundColor,
      child: Column(
        children: [
          createSheetHeader(
            'Results',
            backArrow: true,
            context: context,
            onBack: widget.onBack,
          ),
          if (_runners.isEmpty) ...[
            Center(child: CircularProgressIndicator()),
          ]
          else
            Column(
              mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Head-to-Head View',
                                  style: AppTypography.bodySemibold,
                                ),
                                Switch(
                                  inactiveThumbColor: Colors.grey,
                                  activeColor: AppColors.primaryColor,
                                  inactiveTrackColor: AppColors.primaryColor,
                                  activeTrackColor: Colors.grey,
                                  value: _isHeadToHead,
                                  onChanged: (value) {
                                    setState(() {
                                      _isHeadToHead = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    double buttonWidth = min(constraints.maxWidth * 0.5, 200);
                                    double fontSize = buttonWidth * 0.08;
                                    return ElevatedButton.icon(
                                      onPressed: () => downloadCsv(_calculateOverallTeamResults(), _calculateIndividualResults()),
                                      icon: Image.asset('assets/icon/receive.png', width: 32, height: 32),
                                      label: Text(
                                        'Download CSV Results',
                                        style: TextStyle(fontSize: fontSize),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(200, 60),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                        fixedSize: Size(buttonWidth, 60),
                                      ),
                                    );
                                  },
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await sheet(
                                      context: context,
                                      title: 'Share Results',
                                      body: ShareSheetScreen(
                                        teamResults: _isHeadToHead
                                          ? _calculateHeadToHeadTeamResults()
                                          : _calculateOverallTeamResults(),
                                        individualResults: _calculateIndividualResults(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(100, 60),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),

                        // Overall or Head-to-Head Results
                        if (!_isHeadToHead) ...[
                          Text(
                            'Overall Team Results',
                            style: AppTypography.titleSemibold,
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _calculateOverallTeamResults().length,
                            itemBuilder: (context, index) {
                              final team = _calculateOverallTeamResults()[index];
                              return _buildTeamResultCard(team);
                            },
                          ),
                        ] else ...[
                          Text(
                            'Head-to-Head Results',
                            style: AppTypography.titleSemibold,
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _calculateHeadToHeadTeamResults().length,
                            itemBuilder: (context, index) {
                              final matchup = _calculateHeadToHeadTeamResults()[index];
                              return _buildHeadToHeadCard(matchup);
                            },
                          ),
                        ],
                        const Divider(),
                        // Individual Results Section
                        Text(
                          'Individual Results',
                          style: AppTypography.titleSemibold,
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _calculateIndividualResults().length,
                          itemBuilder: (context, index) {
                            final runner = _calculateIndividualResults()[index];
                            return ListTile(
                              title: Text(
                                '${index + 1}. ${runner['name'] ?? 'Unknown Name'} (${runner['school'] ?? 'Unknown School'})',
                                style: AppTypography.bodyRegular,
                              ),
                              subtitle: Text(
                                'Time: ${runner['finish_time'] ?? 'N/A'} | Grade: ${runner['grade'] ?? 'Unknown'} | Bib: ${runner['bib_number'] ?? 'N/A'}',
                                style: AppTypography.bodyRegular,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                // ]
              ),
                ]
            // ),
          // ],
        ),
        ],
      ),
    );
  }

  // Card for Overall Results
  Widget _buildTeamResultCard(Map<String, dynamic> team) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (team['place'] != null)
                  Text(
                    '${team['place']}. ${team['school']}',
                    style: AppTypography.titleSemibold,
                  ),
                if (team['place'] == null)
                  Text(
                    '${team['school']}',
                    style: AppTypography.titleSemibold,
                  ),
                Text(
                  '${team['score']} Points',
                  style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Scorers: ${team['scorers']}',
              style: AppTypography.bodyRegular,
            ),
            const SizedBox(height: 4),
            if (team['place'] != null)
              Text(
                'Times: ${team['times']}',
                style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  // Card for Head-to-Head Results
  Widget _buildHeadToHeadCard(Map<String, dynamic> matchup) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Matchup Header
            Text(
              '${matchup['team1']?['school'] ?? 'Unknown'} vs ${matchup['team2']?['school'] ?? 'Unknown'}',
              style: AppTypography.titleSemibold,
            ),
            const SizedBox(height: 8),

            // Team 1 Result
            _buildTeamComparison(
              rank: '1',
              team: matchup['team1'],
            ),

            const Divider(color: Colors.grey),

            // Team 2 Result
            _buildTeamComparison(
              rank: '2',
              team: matchup['team2'],
            ),
          ],
        ),
      ),
    );
  }

  // Shared Team Comparison Widget
  Widget _buildTeamComparison({required String rank, required Map<String, dynamic> team}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$rank. ${team['school']}',
              style: AppTypography.bodySemibold,
            ),
            Text(
              '${team['score']} Points',
              style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Scorers: ${team['scorers']}',
          style: AppTypography.bodyRegular,
        ),
        const SizedBox(height: 4),
        Text(
          'Times: ${team['times']}',
          style: AppTypography.bodyRegular.copyWith(color: Colors.grey),
        ),
      ],
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

  List<Map<String, dynamic>> _calculateIndividualResults() {
    final sortedRunners = List<Map<String, dynamic>>.from(_runners);
    sortedRunners.sort((a, b) => a['finishTimeAsDuration'].compareTo(b['finishTimeAsDuration']));
    return sortedRunners;
  }

  List<Map<String, dynamic>> _calculateOverallTeamResults() {
    // Normal team scoring logic (all teams considered together)
    return _calculateTeamResults(_results);
  }

  List<Map<String, dynamic>> _calculateHeadToHeadTeamResults() {
    final schools = _results.map((r) => r.school!).toSet().toList();
    final headToHeadResults = <Map<String, dynamic>>[];

    for (int i = 0; i < schools.length; i++) {
      for (int j = i + 1; j < schools.length; j++) {
        final schoolA = schools[i];
        final schoolB = schools[j];
        final filteredRunners = _results
            .where((r) => r.school == schoolA || r.school == schoolB)
            .toList();

        final teamResults = _calculateTeamResults(filteredRunners);

        // Add the results for the two teams being compared as a group
        final matchup = {
          'team1': teamResults.firstWhere((team) => team['school'] == schoolA, orElse: () => {}),
          'team2': teamResults.firstWhere((team) => team['school'] == schoolB, orElse: () => {}),
        };

        headToHeadResults.add(matchup);
      }
    }

    return headToHeadResults;
  }

  // Get the names of the scoring teams (teams with 5 or more runners)
  // and non-scoring teams
  List<List<String>> _getTeamInfo(List<TimingRecord> allRunners) {
    final scoringTeams = <String>[];
    final nonScoringTeams = <String>[];

    final teams = groupBy(allRunners, (runner) => runner.school!);

    teams.forEach((school, runners) {
      if (runners.length >= 5) {
        scoringTeams.add(school);
      } else {
        nonScoringTeams.add(school);
      }
    });

    return [scoringTeams, nonScoringTeams];
  }

  // Get the runners corresponding to a given team
  List<TimingRecord> _getRunnersForTeam(List<TimingRecord> allRunners, String teamName) {
    return allRunners.where((runner) => runner.school == teamName).toList();
  }

  // Get the runners corresponding to a list of teams
  List<TimingRecord> _getRunnersForTeams(List<TimingRecord> allRunners, List<String> teams) {
    return allRunners.where((runner) => teams.contains(runner.school)).toList();
  }

  List<Map<String, dynamic>> _calculateTeamResults(List<TimingRecord> allRunners) {
    final List<List<String>> teamInfo = _getTeamInfo(allRunners);

    final scoringTeams = teamInfo[0];
    final nonScoringTeams = teamInfo[1];

    final scoringRunners = _getRunnersForTeams(allRunners, scoringTeams);

    // Calculate scores for each team
    final teamScores = <Map<String, dynamic>>[];
    final nonScoringTeamScores = <Map<String, dynamic>>[];
    int place = 1;

    for (var school in scoringTeams) {
      final schoolRunners = _getRunnersForTeam(allRunners, school);

      // Sort runners by time
      schoolRunners.sort((a, b) => loadDurationFromString(a.elapsedTime)!.compareTo(loadDurationFromString(b.elapsedTime)!));

      // Calculate team score and other stats
      final top5 = schoolRunners.take(5).toList();
      final sixthRunner = schoolRunners.length > 5 ? scoringRunners.indexOf(schoolRunners[5]) + 1 : null;
      final seventhRunner = schoolRunners.length > 6 ? scoringRunners.indexOf(schoolRunners[6]) + 1 : null;
      final score = top5.fold<int>(0, (sum, runner) => sum + scoringRunners.indexOf(runner) + 1); // Calculate position based on time
      final scorers = '${top5.map((runner) => '${scoringRunners.indexOf(runner) + 1}').join('+')} ${sixthRunner != null ? '($sixthRunner' : ''}${seventhRunner != null ? '+$seventhRunner' : ''}${sixthRunner != null || seventhRunner != null ? ')' : ''}';

      final split = loadDurationFromString(top5.last.elapsedTime)! - loadDurationFromString(top5.first.elapsedTime)!;
      final formattedSplit = formatDuration(split);
      final avgTime = top5.fold(Duration.zero, (sum, runner) => sum + loadDurationFromString(runner.elapsedTime)!) ~/ 5;
      String formattedAverage = formatDuration(avgTime);

      teamScores.add({
        'place': place++,
        'school': school,
        'score': score,
        'scorers': scorers,
        'split': formattedSplit,
        'averageTime': formattedAverage,
        'times': '$formattedSplit 1-5 Split | $formattedAverage Avg',
        'sixth_runner': sixthRunner,
        'seventh_runner': seventhRunner,
      });
    }

    for (var school in nonScoringTeams) {
      nonScoringTeamScores.add({
        'place': null,
        'school': school,
        'score': 'N/A',
        'scorers': 'N/A',
        'times': 'N/A',
        'sixth_runner': null,
        'seventh_runner': null,
      });
    }

    // Sort teams by score (and apply tiebreakers if necessary)
    teamScores.sort((a, b) {
      if (a['score'] != b['score']) return a['score'].compareTo(b['score']);
      if (a['sixth_runner'] != b['sixth_runner']) return a['sixth_runner']!.compareTo(b['sixth_runner']!);
      if (a['seventh_runner'] != b['seventh_runner']) return a['seventh_runner']!.compareTo(b['seventh_runner']!);
      return 0;
    });

    nonScoringTeamScores.sort((a, b) => a['school'].compareTo(b['school']));


    return [...teamScores, ...nonScoringTeamScores];
  }
}
