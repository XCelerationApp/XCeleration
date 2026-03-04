import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/coach/share_race/controller/share_race_controller.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import '../controller/race_results_controller.dart';
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
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final RaceResultsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RaceResultsController(service: RaceResultsService());
    _controller.loadRaceResults(widget.masterRace);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<RaceResultsController>(
        builder: (context, controller, child) {
          return Material(
            color: AppColors.backgroundColor,
            child: Stack(
              children: [
                if (controller.isLoading) ...[
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ] else if (controller.hasError) ...[
                  Center(
                    child: Text(
                      controller.error!.userMessage,
                      style: AppTypography.titleSemibold,
                    ),
                  ),
                ] else ...[
                  Column(
                    children: [
                      if (controller.raceResultsData == null ||
                          controller
                              .raceResultsData!.individualResults.isEmpty) ...[
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
                                  TeamResultsWidget(
                                    raceResultsData:
                                        controller.raceResultsData!,
                                  ),
                                  IndividualResultsWidget(
                                    raceResultsData:
                                        controller.raceResultsData!,
                                    initialVisibleCount: 5,
                                  ),
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
                if (controller.raceResultsData != null) ...[
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: ShareButton(onPressed: () {
                      ShareRaceController.showShareRaceSheet(
                        context: context,
                        raceResultsData: controller.raceResultsData!,
                        masterRace: widget.masterRace,
                      );
                    }),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
