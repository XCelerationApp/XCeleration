import 'package:flutter/material.dart';
import 'package:xceleration/shared/services/race_results_service.dart';
import 'package:xceleration/coach/race_results/widgets/team_results_widget.dart';
import 'package:xceleration/coach/race_results/widgets/individual_results_widget.dart';
import 'package:xceleration/core/theme/app_colors.dart';

class ReceiveRacePreviewScreen extends StatelessWidget {
  final RaceResultsData data;
  const ReceiveRacePreviewScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(data.resultsTitle)),
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamResultsWidget(raceResultsData: data),
            IndividualResultsWidget(
                raceResultsData: data, initialVisibleCount: 10),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
