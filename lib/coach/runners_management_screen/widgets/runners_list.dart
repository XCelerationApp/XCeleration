import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../race_screen/widgets/runner_record.dart';
import '../controller/runners_management_controller.dart';
import 'runner_list_item.dart';

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

    if (controller.filteredRunners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.mediumColor.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              controller.searchController.text.isEmpty
                  ? 'No Runners Added'
                  : 'No runners found',
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
                  color: AppColors.mediumColor.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Group runners by school
    final groupedRunners = <String, List<RunnerRecord>>{};
    for (var runner in controller.filteredRunners) {
      if (!groupedRunners.containsKey(runner.school)) {
        groupedRunners[runner.school] = [];
      }
      groupedRunners[runner.school]!.add(runner);
    }

    // Sort schools alphabetically
    final sortedSchools = groupedRunners.keys.toList()..sort();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: sortedSchools.length,
        itemBuilder: (context, index) {
          final school = sortedSchools[index];
          final schoolRunners = groupedRunners[school]!;
          final team =
              controller.teams.firstWhereOrNull((team) => team.name == school);
          final schoolColor = team != null ? team.color : Colors.blueGrey[400];

          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, thickness: 1, color: Colors.grey),
                Container(
                  decoration: BoxDecoration(
                    color: schoolColor?.withAlpha((0.12 * 255).round()) ??
                        Colors.grey.withAlpha((0.12 * 255).round()),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  margin: const EdgeInsets.only(right: 16.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 18,
                        color: schoolColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        school,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: schoolColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: schoolColor?.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${schoolRunners.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: schoolColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...schoolRunners.map((runner) => RunnerListItem(
                      runner: runner,
                      controller: controller,
                      onAction: (action) =>
                          controller.handleRunnerAction(action, runner),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}
