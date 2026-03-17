import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/bib_entry.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// A single bib entry row.
///
/// Swipe left to delete. Tap the bib number to edit it inline.
class SwipeBibRowWidget extends StatefulWidget {
  const SwipeBibRowWidget({
    super.key,
    required this.entry,
    required this.position,
    required this.controller,
    this.isNew = false,
  });

  final BibEntry entry;
  final int position;
  final BibRecorderV2Controller controller;
  final bool isNew;

  @override
  State<SwipeBibRowWidget> createState() => _SwipeBibRowWidgetState();
}

class _SwipeBibRowWidgetState extends State<SwipeBibRowWidget> {
  bool _editing = false;
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: '${widget.entry.bib}');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final n = int.tryParse(_textCtrl.text);
    if (n != null && n > 0) widget.controller.editEntry(widget.entry.id, n);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final flag = widget.controller.flagFor(
      widget.entry.bib,
      excludeId: widget.entry.id,
    );
    final runner = widget.controller.runnerFor(widget.entry.bib);

    return Dismissible(
      key: ValueKey(widget.entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        widget.controller.deleteEntry(widget.entry.id);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.redColor,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: Text(
          'Delete',
          style: AppTypography.smallBodySemibold.copyWith(
            color: Colors.white,
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        color: widget.isNew
            ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
            : Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${widget.position}.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.lightColor,
                ),
              ),
            ),
            _editing
                ? SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _textCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: AppTypography.titleSemibold.copyWith(
                        color: AppColors.primaryColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.only(bottom: AppSpacing.xs),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primaryColor,
                            width: 2,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: AppColors.primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => _commit(),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _editing = true;
                        _textCtrl.text = '${widget.entry.bib}';
                      });
                    },
                    child: Container(
                      width: 56,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.borderColor,
                          ),
                        ),
                      ),
                      child: Text(
                        '${widget.entry.bib}',
                        style: AppTypography.titleSemibold.copyWith(
                          color: AppColors.darkColor,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTrailing(flag, runner)),
            const Icon(
              Icons.chevron_left,
              size: 14,
              color: AppColors.lightColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing(String? flag, dynamic runner) {
    if (widget.entry.correctedTo != null) {
      return Text(
        '✓ corrected → #${widget.entry.correctedTo}',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.statusFinished,
        ),
      );
    }
    if (flag == null && runner != null) {
      return Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: runner.teamColor ?? AppColors.mediumColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '${runner.name ?? ''}, ${runner.teamAbbreviation ?? ''}',
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ),
        ],
      );
    }
    if (flag == 'duplicate') {
      return Text(
        '⚠ Duplicate',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.redColor,
        ),
      );
    }
    if (flag == 'unknown') {
      return Text(
        '? Not in roster',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.statusSetup,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
