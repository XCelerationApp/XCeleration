import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../services/roster_importer.dart';

/// Every bib in an import that was already saved with other details, in one
/// list: the coach keeps the saved details or takes the spreadsheet's, for
/// all of them at once or one by one. It used to ask in a dialog per bib.
///
/// Pops with the conflicts whose spreadsheet details to use; closing the
/// sheet keeps every saved runner as it was.
class SavedBibChoicesSheet extends StatefulWidget {
  const SavedBibChoicesSheet({super.key, required this.conflicts});

  final List<RunnerDetailsConflict> conflicts;

  @override
  State<SavedBibChoicesSheet> createState() => _SavedBibChoicesSheetState();
}

class _SavedBibChoicesSheetState extends State<SavedBibChoicesSheet> {
  /// For each conflict, whether to use the spreadsheet's details. Saved by
  /// default: nothing already saved changes unless the coach says so.
  late final List<bool> _useSheet =
      List.filled(widget.conflicts.length, false);

  void _setAll(bool useSheet) =>
      setState(() => _useSheet.fillRange(0, _useSheet.length, useSheet));

  @override
  Widget build(BuildContext context) {
    final count = widget.conflicts.length;
    final allSheet = _useSheet.every((u) => u);
    final allSaved = _useSheet.every((u) => !u);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${count == 1 ? 'This bib belongs' : 'These bibs belong'} to '
          'runners already saved with a different name or grade. Choose '
          'whose details to keep. Either way, each bib is in this race.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        if (count > 1) ...[
          Row(
            children: [
              Expanded(
                child: _AllButton(
                  key: const ValueKey('keep_all_saved'),
                  label: 'Keep All Saved',
                  selected: allSaved,
                  onPressed: () => _setAll(false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _AllButton(
                  key: const ValueKey('use_all_spreadsheet'),
                  label: 'Use All Spreadsheet',
                  selected: allSheet,
                  onPressed: () => _setAll(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final conflict = widget.conflicts[i];
              final saved = conflict.existing;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bib ${saved.bibNumber}',
                      style: AppTypography.smallBodySemibold),
                  const SizedBox(height: AppSpacing.xs),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Choice(
                            key: ValueKey('saved_${saved.bibNumber}'),
                            label: 'Saved',
                            name: saved.name ?? '',
                            grade: saved.grade,
                            selected: !_useSheet[i],
                            onTap: () => setState(() => _useSheet[i] = false),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _Choice(
                            key: ValueKey('sheet_${saved.bibNumber}'),
                            label: 'Spreadsheet',
                            name: conflict.name,
                            grade: conflict.grade,
                            selected: _useSheet[i],
                            onTap: () => setState(() => _useSheet[i] = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FullWidthButton(
          text: 'Done',
          onPressed: () => Navigator.of(context).pop([
            for (var i = 0; i < count; i++)
              if (_useSheet[i]) widget.conflicts[i],
          ]),
        ),
      ],
    );
  }
}

class _AllButton extends StatelessWidget {
  const _AllButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryColor,
        backgroundColor: selected ? AppColors.selectedRoleColor : null,
        side: BorderSide(
            color: selected ? AppColors.primaryColor : AppColors.lightColor),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.name,
    required this.grade,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String name;
  final int? grade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.selectedRoleColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        side: BorderSide(
          color: selected ? AppColors.primaryColor : AppColors.lightColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected
                        ? AppColors.primaryColor
                        : AppColors.mediumColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.mediumColor)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(name, style: AppTypography.bodySemibold),
              if (grade != null)
                Text('Grade $grade',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.mediumColor)),
            ],
          ),
        ),
      ),
    );
  }
}
