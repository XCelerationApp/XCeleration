import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

class RunnerSearchBar extends StatefulWidget {
  const RunnerSearchBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSearchChanged;

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
    // Searches names, bibs, grades and teams at once, so there is no menu
    // to pick which.
    return _SearchField(this);
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
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(
            Icons.search,
            size: 18,
            color: AppColors.mediumColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: state.widget.controller,
              onChanged: (_) => state.widget.onSearchChanged(),
              // Names and bibs, not words to correct.
              autocorrect: false,
              enableSuggestions: false,
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.darkColor,
              ),
              decoration: InputDecoration(
                hintText: 'Search name, bib or team',
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
