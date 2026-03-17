import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Search-by-name section of the resolve sheet, including the text field
/// and the list of fuzzy-match candidates.
class SearchSection extends StatelessWidget {
  const SearchSection({
    super.key,
    required this.controller,
    required this.entry,
    required this.searchCtrl,
    required this.onResolved,
  });

  final FixerController controller;
  final FixerEntry entry;
  final TextEditingController searchCtrl;
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEARCH BY NAME',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.mediumColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: searchCtrl,
          onChanged: controller.search,
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.darkColor,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Singh, Priya, Tom G…',
            hintStyle: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(
                  color: AppColors.primaryColor, width: 1.5),
            ),
          ),
        ),
        if (controller.searchResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _CandidateList(
            results: controller.searchResults,
            entryBib: entry.bib,
            onPick: (runner) {
              controller.resolveWithRunner(entry.id, runner);
              onResolved();
            },
          ),
        ],
        if (searchCtrl.text.isNotEmpty &&
            controller.searchResults.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'No matches',
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.results,
    required this.entryBib,
    required this.onPick,
  });

  final List<Runner> results;
  final int entryBib;
  final ValueChanged<Runner> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: results.map((runner) {
        return _CandidateRow(
          runner: runner,
          entryBib: entryBib,
          onTap: () => onPick(runner),
        );
      }).toList(),
    );
  }
}

class _CandidateRow extends StatefulWidget {
  const _CandidateRow({
    required this.runner,
    required this.entryBib,
    required this.onTap,
  });

  final Runner runner;
  final int entryBib;
  final VoidCallback onTap;

  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Center(
                child: Text(
                  '#${widget.runner.bibNumber}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mediumColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.runner.name ?? widget.runner.bibNumber,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                  if (widget.runner.teamAbbreviation != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (widget.runner.teamColor != null)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: widget.runner.teamColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          widget.runner.teamAbbreviation!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.mediumColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumColor,
            ),
          ],
        ),
      ),
    );
  }
}
