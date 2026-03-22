import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Selector, ChangeNotifierProvider
import 'package:xceleration/core/services/i_sync_service.dart';
import '../controller/runners_management_controller.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../shared/models/database/i_master_race_resolver.dart';
import '../widgets/runner_search_bar.dart';
import '../widgets/runners_list.dart';

// Main Screen
class TeamsAndRunnersManagementWidget extends StatefulWidget {
  final IMasterRaceResolver masterRace;
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool? showHeader;
  final bool isViewMode;

  const TeamsAndRunnersManagementWidget({
    super.key,
    required this.masterRace,
    this.showHeader,
    this.onBack,
    this.onContentChanged,
    this.isViewMode = false,
  });

  @override
  State<TeamsAndRunnersManagementWidget> createState() =>
      _TeamsAndRunnersManagementWidgetState();
}

class _TeamsAndRunnersManagementWidgetState
    extends State<TeamsAndRunnersManagementWidget> {
  late RunnersManagementController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RunnersManagementController(
      masterRace: widget.masterRace,
      showHeader: widget.showHeader ?? true,
      onBack: widget.onBack,
      onContentChanged: widget.onContentChanged,
      isViewMode: widget.isViewMode,
      syncStream: context.read<ISyncService>().syncEvents,
    );
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      // Selector gates rebuilds of the header/search section to only the
      // fields those sections actually read. RunnersList subscribes to the
      // controller independently, so it is placed outside the Selector —
      // search/filter notifications no longer cause a full-column rebuild.
      child: Selector<RunnersManagementController,
          ({bool showHeader, bool isLoading, int totalRunnerCount, String searchAttribute})>(
        selector: (_, c) => (
          showHeader: c.showHeader,
          isLoading: c.isLoading,
          totalRunnerCount: c.totalRunnerCount,
          searchAttribute: c.searchAttribute,
        ),
        builder: (context, data, _) {
          return Material(
            color: AppColors.backgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (data.showHeader)
                  ColoredBox(
                    color: AppColors.backgroundColor,
                    child: _buildHeader(_controller),
                  ),
                if (!data.isLoading)
                  ColoredBox(
                    color: AppColors.backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: _buildSearchSection(),
                    ),
                  ),
                Expanded(
                  child: RunnersList(controller: _controller),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(RunnersManagementController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onBack != null)
                createBackArrow(context, onBack: widget.onBack),
              Text(
                'Runners',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              if (controller.totalRunnerCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${controller.totalRunnerCount}',
                  style: AppTypography.captionBold.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ],
              const Spacer(),
              if (!controller.isViewMode)
                _AddTeamButton(
                  onTap: () =>
                      _controller.showAddTeamChoiceSheet(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return RunnerSearchBar(
      controller: _controller.searchController,
      searchAttribute: _controller.searchAttribute,
      onSearchChanged: () => _controller
          .filterRaceRunners(_controller.searchController.text.trim()),
      onAttributeChanged: (value) {
        _controller.setSearchAttribute(value!);
      },
      isViewMode: _controller.isViewMode,
    );
  }
}

class _AddTeamButton extends StatelessWidget {
  const _AddTeamButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: AppColors.primaryColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppColors.primaryColor),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Add Team',
              style: AppTypography.smallBodySemibold.copyWith(
                color: AppColors.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
