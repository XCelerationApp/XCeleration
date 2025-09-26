import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/race_runner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/database/team.dart';
import '../controller/runners_management_controller.dart';
import 'runner_list_item.dart';
import 'add_runner_button.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'team_header_tile.dart';

class RunnersList extends StatelessWidget {
  final RunnersManagementController controller;
  const RunnersList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      );
    }

    return FutureBuilder<Map<Team, List<RaceRunner>>>(
      future: controller.masterRace.filteredSearchResults,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          );
        }

        final teamToRaceRunnersMap = snapshot.data!;

        if (teamToRaceRunnersMap.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 48,
                  color: ColorUtils.withOpacity(AppColors.mediumColor, 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.searchController.text.isEmpty
                      ? 'No Teams or Runners Added'
                      : 'No teams or runners found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mediumColor,
                  ),
                ),
                if (controller.searchController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search',
                    style: TextStyle(
                      fontSize: 16,
                      color: ColorUtils.withOpacity(AppColors.mediumColor, 0.7),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return _buildRunnersList(context, teamToRaceRunnersMap);
      },
    );
  }

  Widget _buildRunnersList(
      BuildContext context, Map<Team, List<RaceRunner>> teamToRaceRunnersMap) {
    // Show all teams, including those with no runners
    final teams = teamToRaceRunnersMap.keys.toList();
    teams.sort((a, b) => a.name!.compareTo(b.name!));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 0, bottom: 8),
        itemCount: teams.length,
        itemBuilder: (context, index) {
          final team = teams[index];
          final teamRaceRunners = teamToRaceRunnersMap[team] ?? [];

          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, thickness: 1, color: Colors.grey),
                TeamHeaderTile(
                  team: team,
                  runnerCount: teamRaceRunners.length,
                  controller: controller,
                  isViewMode: controller.isViewMode,
                ),
                ...teamRaceRunners.map((raceRunner) {
                  final runner = raceRunner.runner;
                  return RunnerListItem(
                    runner: runner,
                    team: team,
                    controller: controller,
                    onAction: (action) => controller.handleRaceRunnerAction(
                        context, action, raceRunner),
                    isViewMode: controller.isViewMode,
                  );
                }),
                AddRunnerButton(
                  team: team,
                  controller: controller,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
