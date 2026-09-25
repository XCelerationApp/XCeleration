import 'package:flutter/material.dart';

import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import '../utils/sheet_utils.dart';

/// Asks which tab of a spreadsheet to import: one tab, or all of them.
/// Returns the chosen tab names, or null if the coach backs out.
Future<List<String>?> chooseSheetTabs(
    BuildContext context, String fileName, List<String> tabs) async {
  final choice = await sheet(
    context: context,
    title: 'Which Tab?',
    body: SheetTabChooser(fileName: fileName, tabs: tabs),
  );
  return choice is List<String> ? choice : null;
}

/// The list [chooseSheetTabs] shows: All tabs first, then each tab.
class SheetTabChooser extends StatelessWidget {
  const SheetTabChooser({super.key, required this.fileName, required this.tabs});

  final String fileName;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '"$fileName" has ${tabs.length} tabs. A tab without a Team column '
          'uses the tab\'s name as the team.',
          style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
        ),
        const SizedBox(height: AppSpacing.lg),
        _TabOption(
          icon: Icons.layers_outlined,
          label: 'All tabs',
          detail: 'Import every tab, each as its own team',
          primary: true,
          onTap: () => Navigator.pop(context, tabs),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _TabOption(
              icon: Icons.tab_outlined,
              label: tabs[i],
              onTap: () => Navigator.pop(context, [tabs[i]]),
            ),
          ),
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
    this.detail,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final bool primary;
  final VoidCallback onTap;

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
                    if (detail != null)
                      Text(detail!,
                          style: AppTypography.smallBodyRegular
                              .copyWith(color: fg.withValues(alpha: 0.85))),
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
