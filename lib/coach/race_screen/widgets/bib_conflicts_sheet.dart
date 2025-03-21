import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/app_colors.dart';
import '../../resolve_bib_number_screen/screen/resolve_bib_number_screen.dart';
import 'runner_record.dart';

class BibConflictsSheet extends StatelessWidget {
  final List<RunnerRecord> runnerRecords;
  final int raceId;

  const BibConflictsSheet({
    super.key,
    required this.runnerRecords,
    required this.raceId,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Resolve Bib Number Conflicts',
                style: AppTypography.titleSemibold,
              ),
            ),
            Expanded(
              child: ResolveBibNumberScreen(
                raceId: raceId, // This will be provided by the parent
                records: runnerRecords,
                onComplete: (resolvedRecords) {
                  Navigator.pop(context, resolvedRecords);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
