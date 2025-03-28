import 'package:flutter/material.dart';
import 'package:xcelerate/coach/share_race/controller/share_race_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../widgets/share_button.dart';
import '../widgets/results_overview_widget.dart';
import '../widgets/collapsible_results_widget.dart';
import '../widgets/team_results_widget.dart';
import '../widgets/collapsible_head_to_head_results.dart';
import '../controller/results_screen_controller.dart';

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
  late final ResultsScreenController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ResultsScreenController(raceId: widget.raceId);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundColor,
      child: Stack(
        children: [
          if (_controller.isLoading) ...[
            const Center(
              child: CircularProgressIndicator(),
            ),
          ] else ...[
            Column(
              children: [
                if (_controller.individualResults.isEmpty) ...[
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overview section
                            ResultsOverviewWidget(
                              controller: _controller,
                            ),
                            
                            // View toggle control (Overall / Head to Head)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16.0),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                                                  _controller.isHeadToHead = false;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: !_controller.isHeadToHead
                                                      ? AppColors.primaryColor
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      const BorderRadius.horizontal(left: Radius.circular(8)),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Overall',
                                                    style: AppTypography.bodySemibold.copyWith(
                                                      color: !_controller.isHeadToHead ? Colors.white : Colors.black54,
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
                                                  _controller.isHeadToHead = true;
                                                });
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: _controller.isHeadToHead
                                                      ? AppColors.primaryColor
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      const BorderRadius.horizontal(right: Radius.circular(8)),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'Head to Head',
                                                    style: AppTypography.bodySemibold.copyWith(
                                                      color: _controller.isHeadToHead ? Colors.white : Colors.black54,
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
                            
                            // Content based on selected view
                            if (!_controller.isHeadToHead) ...[
                              // Team Results Widget
                              TeamResultsWidget(
                                teams: _controller.overallTeamResults,
                                expandedTeams: _controller.expandedTeams,
                                onToggleTeam: (teamName) {
                                  setState(() {
                                    _controller.toggleTeamExpansion(teamName);
                                  });
                                },
                              ),
                              
                              // Individual Results Widget
                              CollapsibleResultsWidget(
                                allResults: _controller.individualResults,
                                initialVisibleCount: 3,
                                isExpanded: _controller.expandedIndividuals,
                                onToggleExpansion: () {
                                  setState(() {
                                    _controller.toggleIndividualExpansion();
                                  });
                                },
                              ),
                            ] else ...[
                              // Head to Head Results
                              CollapsibleHeadToHeadResults(
                                headToHeadTeamResults: _controller.headToHeadTeamResults,
                                expandedMatchups: _controller.expandedTeams,
                                onToggleMatchup: (matchupId) {
                                  setState(() {
                                    _controller.toggleTeamExpansion(matchupId);
                                  });
                                },
                              ),
                            ],
                            
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
          Positioned(
            bottom: 16,
            right: 16,
            child: ShareButton(onPressed: () {
              ShareRaceController.showShareRaceSheet(
                context: context,
                headToHeadTeamResults: _controller.headToHeadTeamResults,
                individualResults: _controller.individualResults,
                overallTeamResults: _controller.overallTeamResults,
              );
            }),
          ),
        ],
      ),
    );
  }
}
