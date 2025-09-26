import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/info_chip.dart';
import '../controller/resolve_bib_number_controller.dart';

class SearchResults extends StatelessWidget {
  final ResolveBibNumberController controller;

  const SearchResults({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: controller.searchResults.length,
      itemBuilder: (context, index) {
        final raceRunner = controller.searchResults[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: AppColors.primaryColor.withAlpha((0.2 * 255).round()),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                raceRunner.runner.name!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InfoChip(
                        label: 'Bib ${raceRunner.runner.bibNumber!}',
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      InfoChip(
                        label: 'Grade ${raceRunner.runner.grade}',
                        color: AppColors.mediumColor,
                      ),
                      const SizedBox(width: 8),
                      // Team information will be loaded asynchronously
                      Expanded(
                        child: InfoChip(
                          label: raceRunner.team.name!,
                          color: AppColors.mediumColor,
                        ),
                      )
                    ],
                  ),
                ],
              ),
              onTap: () => controller.assignExistingRaceRunner(raceRunner),
            ),
          ),
        );
      },
    );
  }
}
