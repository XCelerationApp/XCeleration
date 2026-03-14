import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

class RunnerSearchBar extends StatefulWidget {
  const RunnerSearchBar({
    super.key,
    required this.controller,
    required this.searchAttribute,
    required this.onSearchChanged,
    required this.onAttributeChanged,
    this.onDeleteAll,
    this.isViewMode = false,
  });

  final TextEditingController controller;
  final String searchAttribute;
  final VoidCallback onSearchChanged;
  final ValueChanged<String?> onAttributeChanged;

  /// Kept for API compatibility; no longer rendered in the UI.
  final VoidCallback? onDeleteAll;
  final bool isViewMode;

  @override
  State<RunnerSearchBar> createState() => _RunnerSearchBarState();
}

class _RunnerSearchBarState extends State<RunnerSearchBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _clearSearch() {
    widget.controller.clear();
    widget.onSearchChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SearchField(this)),
        const SizedBox(width: AppSpacing.sm),
        _AttributeDropdown(
          value: widget.searchAttribute,
          onChanged: widget.onAttributeChanged,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(this.state);

  final _RunnerSearchBarState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(
            Icons.search,
            size: 18,
            color: AppColors.primaryColor.withValues(alpha: 0.8),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: state.widget.controller,
              onChanged: (_) => state.widget.onSearchChanged(),
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.darkColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search runners…',
                hintStyle: AppTypography.smallBodyRegular.copyWith(
                  color: AppColors.mediumColor.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: state._hasText ? 1.0 : 0.0,
            duration: AppAnimations.fast,
            child: state._hasText
                ? GestureDetector(
                    onTap: state._clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.mediumColor,
                      ),
                    ),
                  )
                : const SizedBox(width: AppSpacing.xl),
          ),
        ],
      ),
    );
  }
}

class _AttributeDropdown extends StatelessWidget {
  const _AttributeDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  static const _options = ['All', 'Bib Number', 'Name', 'Grade', 'Team'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          focusColor: Colors.transparent,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.primaryColor,
          ),
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.darkColor,
          ),
          items: _options
              .map(
                (opt) => DropdownMenuItem(
                  value: opt,
                  child: Text(
                    opt,
                    style: AppTypography.smallBodyRegular.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
