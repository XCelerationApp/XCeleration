import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import '../controller/runners_management_controller.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../shared/models/database/master_race.dart';
import '../widgets/runner_search_bar.dart';
import '../widgets/runners_list.dart';

// Main Screen
class TeamsAndRunnersManagementWidget extends StatefulWidget {
  final MasterRace masterRace;
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool? showHeader;
  final bool isViewMode;

  // Add a static method that can be called from outside
  static Future<bool> checkMinimumRunnersLoaded(MasterRace masterRace) async {
    final teamToRaceRunnersMap = await masterRace.teamtoRaceRunnersMap;

    // If there are no teams yet, we cannot proceed
    if (teamToRaceRunnersMap.isEmpty) {
      return false;
    }

    for (final entry in teamToRaceRunnersMap.entries) {
      if (entry.value.isEmpty) {
        return false;
      }
    }

    return true;
  }

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
      child: Consumer<RunnersManagementController>(
        builder: (context, controller, child) {
          return Material(
            color: AppColors.surfaceColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (controller.showHeader)
                      _buildHeader(controller),
                    if (!controller.isLoading) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: _buildSearchSection(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: RunnersList(controller: controller),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(RunnersManagementController controller) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.md,
      ),
      child: Column(
        children: [
          createSheetHandle(height: 5, width: 50),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onBack != null)
                createBackArrow(context, onBack: widget.onBack),
              Text(
                'Runners',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
              if (controller.totalRunnerCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${controller.totalRunnerCount}',
                  style: AppTypography.titleLarge.copyWith(
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
        setState(() {
          _controller.searchAttribute = value!;
          _controller
              .filterRaceRunners(_controller.searchController.text.trim());
        });
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
          color: Colors.transparent,
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
