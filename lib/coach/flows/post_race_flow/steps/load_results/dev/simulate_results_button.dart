import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';

import '../controller/load_results_controller.dart';
import 'race_simulator.dart';

/// Debug builds only: loads simulated Timer and Bib Recorder data, and shows
/// the answer key (the mistakes made and the true results) to check against.
class SimulateResultsButton extends StatefulWidget {
  final LoadResultsController controller;

  const SimulateResultsButton({super.key, required this.controller});

  @override
  State<SimulateResultsButton> createState() => _SimulateResultsButtonState();
}

class _SimulateResultsButtonState extends State<SimulateResultsButton> {
  SimulatedRace? _last;

  Future<void> _simulate() async {
    final scenario = await showModalBottomSheet<SimulatedScenario>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Simulate devices (debug)',
                  style: AppTypography.bodySemibold),
              subtitle: Text('Loads made-up Timer and Bib Recorder data for '
                  'this race\'s runners.'),
            ),
            for (final s in SimulatedScenario.values)
              ListTile(
                title: Text(s.label),
                subtitle: Text(s.description),
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (scenario == null || !mounted) return;
    await widget.controller.resetDevices();
    if (!mounted) return;
    final race =
        await widget.controller.loadSimulatedResults(context, scenario);
    if (race == null || !mounted) return;
    setState(() => _last = race);
    await _showAnswerKey(race);
  }

  Future<void> _showAnswerKey(SimulatedRace race) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Answer key'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final note in race.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $note', style: AppTypography.bodyRegular),
                ),
              const Divider(),
              for (final f in race.answerKey)
                Text(
                  '${f.place}. ${f.runner.runner.name} '
                  '(#${f.runner.runner.bibNumber})  ${f.time}',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.darkColor),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: _simulate,
          child: const Text('Simulate devices (debug)'),
        ),
        if (_last != null)
          TextButton(
            onPressed: () => _showAnswerKey(_last!),
            child: const Text('Answer key'),
          ),
      ],
    );
  }
}
