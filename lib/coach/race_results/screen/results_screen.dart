import 'package:flutter/material.dart';
import 'package:xcelerate/coach/share_race/controller/share_race_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../widgets/share_button.dart';
import '../widgets/individual_results_widget.dart';
import '../widgets/head_to_head_results.dart';
import '../widgets/team_results_widget.dart';
import '../controller/race_results_controller.dart';
import 'package:xcelerate/utils/database_helper.dart';


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
  late final RaceResultsController _controller;
  @override
  void initState() {
    super.initState();
    _controller = RaceResultsController(raceId: widget.raceId, dbHelper: DatabaseHelper.instance);
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_controller.headToHeadTeamResults != null &&
                                _controller.headToHeadTeamResults!.isNotEmpty &&
                                _controller.overallTeamResults.length == 2) ...[
                              // Head to Head Results
                              HeadToHeadResults(
                                controller: _controller,
                              ),
                            ] else ...[
                              TeamResultsWidget(
                                controller: _controller,
                              ),
                            ],
                            // Individual Results Widget
                            IndividualResultsWidget(
                              controller: _controller,
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
          Positioned(
            bottom: 16,
            right: 16,
            child: ShareButton(onPressed: () {
              ShareRaceController.showShareRaceSheet(
                context: context,
                controller: _controller,
              );
            }),
          ),
        ],
      ),
    );
  }
}
