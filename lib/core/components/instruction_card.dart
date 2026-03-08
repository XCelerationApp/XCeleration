import 'package:flutter/material.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../utils/color_utils.dart';

class InstructionCard extends StatelessWidget {
  final String title;
  final List<InstructionItem> instructions;
  final Color? accentColor;
  final IconData? icon;
  final bool initiallyExpanded;

  const InstructionCard({
    super.key,
    required this.title,
    required this.instructions,
    this.accentColor,
    this.icon = Icons.info_outline,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          side: BorderSide(
            color: ColorUtils.withOpacity(color, AppOpacity.strong),
            width: 0.5,
          ),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Row(
            children: [
              Container(
                width: AppSpacing.xxl,
                height: AppSpacing.xxl,
                decoration: BoxDecoration(
                  color: ColorUtils.withOpacity(color, AppOpacity.light),
                  borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: Icon(Icons.arrow_drop_down, color: color),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: instructions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructionItem extends StatelessWidget {
  final String number;
  final String text;
  final Color? accentColor;

  const InstructionItem({
    super.key,
    required this.number,
    required this.text,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(color, AppOpacity.light),
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
