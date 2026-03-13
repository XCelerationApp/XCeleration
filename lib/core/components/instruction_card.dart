import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_opacity.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';
import '../utils/color_utils.dart';

class InstructionCard extends StatefulWidget {
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
  State<InstructionCard> createState() => _InstructionCardState();
}

class _InstructionCardState extends State<InstructionCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppColors.primaryColor;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        side: BorderSide(
          color: ColorUtils.withOpacity(color, AppOpacity.strong),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: AppSpacing.xxl,
                    height: AppSpacing.xxl,
                    decoration: BoxDecoration(
                      color: ColorUtils.withOpacity(color, AppOpacity.light),
                      borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                    ),
                    child: Icon(widget.icon, color: color, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.titleMedium.copyWith(color: color),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: AppAnimations.standard,
                    curve: AppAnimations.spring,
                    child: Icon(Icons.arrow_drop_down, color: color),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppAnimations.standard,
            curve: AppAnimations.spring,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.instructions,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
                style: AppTypography.smallBodySemibold.copyWith(color: color),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTypography.smallBodyRegular),
          ),
        ],
      ),
    );
  }
}
