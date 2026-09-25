import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../core/app_error.dart';
import '../../../../../../core/components/primary_button.dart';
import '../../../../../../core/theme/app_border_radius.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/theme/app_spacing.dart';
import '../../../../../../core/theme/typography.dart';
import '../../../../../../core/utils/sheet_utils.dart';

/// Offers to move every time for a Timer who pressed Start late or early, and
/// shows the move once made, with a way back.
class AdjustTimesTile extends StatelessWidget {
  const AdjustTimesTile({
    super.key,
    required this.shift,
    required this.onShift,
  });

  /// How far the times have been moved so far.
  final Duration shift;

  /// Moves every time by the given amount; returns why not, if refused.
  final AppError? Function(Duration by) onShift;

  @override
  Widget build(BuildContext context) {
    final moved = shift != Duration.zero;
    return Row(
      children: [
        Expanded(
          child: Text(
            moved
                ? 'All times moved ${describeShift(shift)}.'
                : 'Timer started late or early?',
            style: AppTypography.bodyRegular
                .copyWith(color: AppColors.mediumColor),
          ),
        ),
        TextButton(
          onPressed: moved
              ? () => onShift(-shift)
              : () => sheet(
                    context: context,
                    title: 'Adjust All Times',
                    body: _AdjustTimesForm(onShift: onShift),
                  ),
          child: Text(moved ? 'Undo' : 'Adjust Times'),
        ),
      ],
    );
  }
}

/// '5.0 seconds later' or '1.5 seconds earlier'.
String describeShift(Duration shift) {
  final seconds = (shift.inMilliseconds.abs() / 1000).toStringAsFixed(1);
  return '$seconds seconds ${shift.isNegative ? 'earlier' : 'later'}';
}

class _AdjustTimesForm extends StatefulWidget {
  const _AdjustTimesForm({required this.onShift});

  final AppError? Function(Duration by) onShift;

  @override
  State<_AdjustTimesForm> createState() => _AdjustTimesFormState();
}

class _AdjustTimesFormState extends State<_AdjustTimesForm> {
  final _seconds = TextEditingController();
  bool _late = true;
  String? _error;

  @override
  void dispose() {
    _seconds.dispose();
    super.dispose();
  }

  void _apply() {
    final seconds = double.tryParse(_seconds.text.trim());
    if (seconds == null || seconds <= 0) {
      setState(() => _error = 'Enter how many seconds, such as 5 or 2.5.');
      return;
    }
    final by = Duration(milliseconds: (seconds * 1000).round());
    final refused = widget.onShift(_late ? by : -by);
    if (refused != null) {
      setState(() => _error = refused.userMessage);
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
          Text(
            'If the Timer pressed Start after the gun, every time is short by '
            'the same amount. Started late adds the seconds to every time; '
            'started early takes them off.',
            style: AppTypography.bodyRegular
                .copyWith(color: AppColors.mediumColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Started late')),
              ButtonSegment(value: false, label: Text('Started early')),
            ],
            selected: {_late},
            onSelectionChanged: (s) => setState(() => _late = s.single),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _seconds,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Seconds',
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
            ),
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: AppSpacing.lg),
          FullWidthButton(text: 'Move All Times', onPressed: _apply),
        ],
      ),
    );
  }
}
