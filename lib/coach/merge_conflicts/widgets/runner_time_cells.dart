import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../utils/timing_data_converter.dart';

/// Helper widget for displaying a time string in cell style.
class TimeDisplay extends StatelessWidget {
  final String time;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Color color;
  const TimeDisplay({
    super.key,
    required this.time,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = -0.2,
    this.color = AppColors.darkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      time.isNotEmpty ? time : '—',
      style: AppTypography.smallBodySemibold.copyWith(
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

/// Helper for action icons (e.g., add, remove)
class CellActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  const CellActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// Confirmed runner time cell (was ConfirmedTime)
class ConfirmedRunnerTimeCell extends StatelessWidget {
  final String time;
  const ConfirmedRunnerTimeCell({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TimeDisplay(time: time),
        ],
      ),
    );
  }
}

class ExtraTimeCell extends StatelessWidget {
  final String time;
  final void Function() onRemoveExtraTime;

  const ExtraTimeCell({
    super.key,
    required this.time,
    required this.onRemoveExtraTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 2),
        Expanded(
          child: TimeDisplay(time: time),
        ),
        CellActionIcon(
          icon: Icons.close,
          tooltip: 'Remove extra time',
          onPressed: () => onRemoveExtraTime(),
        ),
      ],
    );
  }
}

class MissingTimeCell extends StatefulWidget {
  final TextEditingController controller;
  final String time;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onChanged;
  final VoidCallback? onAddTime;
  final String? validationError;
  final bool autofocus;
  final bool isOriginallyTBD;
  final UIRecord record;

  const MissingTimeCell({
    super.key,
    required this.controller,
    required this.time,
    required this.onSubmitted,
    required this.onChanged,
    this.onAddTime,
    this.validationError,
    this.autofocus = false,
    this.isOriginallyTBD = false,
    required this.record,
  });

  @override
  State<MissingTimeCell> createState() => _MissingTimeCellState();
}

class _MissingTimeCellState extends State<MissingTimeCell> {
  late final FocusNode _focusNode;
  bool _shouldAutofocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _shouldAutofocus = widget.autofocus;
  }

  @override
  void didUpdateWidget(MissingTimeCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only set autofocus once, don't keep refocusing
    if (widget.autofocus && !oldWidget.autofocus) {
      _shouldAutofocus = true;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        return AnimatedBuilder(
          animation: widget.record,
          builder: (context, child) {
            final hasError = widget.record.validationError != null &&
                widget.record.validationError!.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isOriginallyTBD) ...[
                  // TBD entries are always editable textboxes
                  TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: _shouldAutofocus,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Enter missing time',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: const OutlineInputBorder(),
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                      errorText:
                          hasError ? widget.record.validationError : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, // Reduced horizontal padding
                        vertical: 0, // Increased vertical padding
                      ),
                    ),
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                    onChanged: widget.onChanged,
                    onSubmitted: (value) {
                      _shouldAutofocus =
                          false; // Don't autofocus after submission
                      widget.onSubmitted(value);
                    },
                    onEditingComplete: () {
                      _shouldAutofocus =
                          false; // Don't autofocus after editing complete
                      // Also trigger validation on editing complete (focus loss)
                      final currentValue = widget.controller.text;
                      if (currentValue.isNotEmpty && currentValue != 'TBD') {
                        widget.onSubmitted(currentValue);
                      }
                      // Allow focus to be lost
                      _focusNode.unfocus();
                    },
                    onTap: () {
                      // Clear TBD when tapped
                      if (widget.controller.text == 'TBD') {
                        widget.controller.clear();
                      }
                    },
                  ),
                ] else ...[
                  if (widget.onAddTime != null) ...[
                    Center(
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: TimeDisplay(
                                time: widget.controller.text,
                                color:
                                    hasError ? Colors.red : AppColors.darkColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: CellActionIcon(
                                icon: Icons.add_circle_outline,
                                tooltip: 'Insert new time slot',
                                onPressed: widget.onAddTime,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: TimeDisplay(
                        time: widget.controller.text,
                        color: hasError ? Colors.red : AppColors.darkColor,
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        );
      },
    );
  }
}
