import 'package:flutter/material.dart';

import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import '../utils/sheet_utils.dart';

/// Asks which tabs of a spreadsheet to import, any number of them, such as
/// the boys' and girls' tabs of the schools racing. Returns the chosen tab
/// names in sheet order, or null if the coach backs out.
Future<List<String>?> chooseSheetTabs(
    BuildContext context, String fileName, List<String> tabs) async {
  final choice = await sheet(
    context: context,
    title: 'Which Tabs?',
    body: SheetTabChooser(fileName: fileName, tabs: tabs),
  );
  return choice is List<String> ? choice : null;
}

/// The checklist [chooseSheetTabs] shows: Select all, then each tab.
class SheetTabChooser extends StatefulWidget {
  const SheetTabChooser({super.key, required this.fileName, required this.tabs});

  final String fileName;
  final List<String> tabs;

  @override
  State<SheetTabChooser> createState() => _SheetTabChooserState();
}

class _SheetTabChooserState extends State<SheetTabChooser> {
  final _chosen = <String>{};

  bool get _allChosen => _chosen.length == widget.tabs.length;

  @override
  Widget build(BuildContext context) {
    final count = _chosen.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '"${widget.fileName}" has ${widget.tabs.length} tabs. Tick the ones '
          'to import. A tab without a Team column uses the tab\'s name as '
          'the team.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          key: const ValueKey('select_all_tabs'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primaryColor,
          title: Text('Select all', style: AppTypography.bodySemibold),
          value: _allChosen ? true : (_chosen.isEmpty ? false : null),
          tristate: true,
          onChanged: (_) => setState(() {
            if (_allChosen) {
              _chosen.clear();
            } else {
              _chosen.addAll(widget.tabs);
            }
          }),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final tab in widget.tabs)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primaryColor,
                  title: Text(tab, style: AppTypography.bodyRegular),
                  value: _chosen.contains(tab),
                  onChanged: (on) => setState(() {
                    if (on ?? false) {
                      _chosen.add(tab);
                    } else {
                      _chosen.remove(tab);
                    }
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _TabOption(
          icon: Icons.download_outlined,
          label: count == 0
              ? 'Tick the tabs to import'
              : 'Import $count ${count == 1 ? 'tab' : 'tabs'}',
          primary: count > 0,
          onTap: count == 0
              ? null
              : () => Navigator.pop(context, [
                    for (final tab in widget.tabs)
                      if (_chosen.contains(tab)) tab,
                  ]),
        ),
      ],
    );
  }
}

class _TabOption extends StatelessWidget {
  const _TabOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.darkColor;
    return Material(
      color: primary ? AppColors.primaryColor : AppColors.surfaceColor,
      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: primary ? Colors.white : AppColors.primaryColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTypography.bodySemibold.copyWith(color: fg)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}
