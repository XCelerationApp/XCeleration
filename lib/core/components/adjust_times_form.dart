import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_error.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import 'primary_button.dart';

/// '5.0 seconds later' or '1.5 seconds earlier'.
String describeShift(Duration shift) {
  final seconds = (shift.inMilliseconds.abs() / 1000).toStringAsFixed(1);
  return '$seconds seconds ${shift.isNegative ? 'earlier' : 'later'}';
}

/// Asks how many seconds early or late Start was pressed, and moves every
/// time by that much.
class AdjustTimesForm extends StatefulWidget {
  const AdjustTimesForm({
    super.key,
    required this.onShift,
    required this.explanation,
  });

  /// Moves every time by the given amount; returns why not, if refused.
  final AppError? Function(Duration by) onShift;

  /// What moving the times does, shown above the choices.
  final String explanation;

  @override
  State<AdjustTimesForm> createState() => _AdjustTimesFormState();
}

class _AdjustTimesFormState extends State<AdjustTimesForm> {
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
            widget.explanation,
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
