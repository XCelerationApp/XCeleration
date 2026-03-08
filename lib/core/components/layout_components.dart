import 'package:flutter/material.dart';
import '../theme/app_animations.dart';
import '../theme/app_border_radius.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/typography.dart';

/// Layout and structural UI components
/// This file contains widgets for organizing and structuring content

/// Reusable search bar widget with animated focus state.
class SearchBarWidget extends StatefulWidget {
  final String? hintText;
  final String? value;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool isCompact;

  const SearchBarWidget({
    super.key,
    this.hintText,
    this.value,
    this.onChanged,
    this.onClear,
    this.isCompact = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  bool _isFocused = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      curve: AppAnimations.spring,
      margin: EdgeInsets.all(widget.isCompact ? AppSpacing.sm : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: _isFocused ? AppColors.primaryColor : AppColors.lightColor,
        ),
      ),
      child: TextField(
        focusNode: _focusNode,
        controller:
            widget.value != null ? TextEditingController(text: widget.value) : null,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: widget.value != null && widget.value!.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: widget.onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: widget.isCompact ? AppSpacing.md : AppSpacing.lg,
          ),
        ),
      ),
    );
  }
}

/// Reusable section header widget
class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool isCompact;

  const SectionHeaderWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
        vertical: isCompact ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: isCompact
                      ? AppTypography.titleMedium
                      : AppTypography.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTypography.bodyRegular
                        .copyWith(color: AppColors.mediumColor),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
