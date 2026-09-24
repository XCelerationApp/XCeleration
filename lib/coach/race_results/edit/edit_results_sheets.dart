import 'package:flutter/material.dart';

import '../../../core/components/primary_button.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../bib_conflict_resolution/utils/ordinal.dart';

/// Everyone in the race, searchable by name or bib, for choosing who finished
/// at a place. A runner already in the results shows their place, since
/// choosing them swaps the two.
class RunnerPicker extends StatefulWidget {
  const RunnerPicker({
    super.key,
    required this.runners,
    required this.placeOf,
    required this.onPicked,
  });

  final List<RaceRunner> runners;
  final int? Function(RaceRunner) placeOf;
  final void Function(RaceRunner) onPicked;

  @override
  State<RunnerPicker> createState() => _RunnerPickerState();
}

class _RunnerPickerState extends State<RunnerPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final r in widget.runners)
        if (q.isEmpty ||
            (r.runner.name ?? '').toLowerCase().contains(q) ||
            (r.runner.bibNumber ?? '').contains(q))
          r,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search by name or bib',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final runner = shown[i];
              final place = widget.placeOf(runner);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(runner.runner.name ?? 'Unnamed runner',
                    style: AppTypography.bodyRegular),
                subtitle: Text(
                  '${runner.team.name ?? ''} · #${runner.runner.bibNumber}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.mediumColor),
                ),
                trailing: place == null
                    ? null
                    : Text('Now ${ordinal(place)}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.mediumColor)),
                onTap: () => widget.onPicked(runner),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A time for one place, checked by [onSubmit], which returns why it cannot
/// be used, or null once it has been.
class TimeEntry extends StatefulWidget {
  const TimeEntry({super.key, required this.initial, required this.onSubmit});

  final Duration initial;
  final String? Function(Duration) onSubmit;

  @override
  State<TimeEntry> createState() => _TimeEntryState();
}

class _TimeEntryState extends State<TimeEntry> {
  late final _text =
      TextEditingController(text: TimeFormatter.formatDuration(widget.initial));
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final time = TimeFormatter.loadDurationFromString(_text.text.trim());
    final error = time == null
        ? 'Enter a time such as 15:04.32.'
        : widget.onSubmit(time);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _text,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Time',
              hintText: 'mm:ss.hh',
              errorText: _error,
              errorMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FullWidthButton(text: 'Save Time', onPressed: _submit),
        ],
      ),
    );
  }
}
