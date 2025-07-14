import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/runners_management_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/button_components.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../shared/models/database/master_race.dart';
import '../widgets/list_titles.dart';
import '../widgets/runner_search_bar.dart';
import '../widgets/runners_list.dart';

// Main Screen
class TeamsAndRunnersManagementWidget extends StatefulWidget {
  final int raceId;
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool? showHeader;
  final bool isViewMode;

  // Add a static method that can be called from outside
  static Future<bool> checkMinimumRunnersLoaded(int raceId) async {
    final masterRace = MasterRace.getInstance(raceId);
    final teamToRaceRunnersMap = await masterRace.teamtoRaceRunnersMap;
    for (final runners in teamToRaceRunnersMap.values) {
      if (runners.isEmpty) {
        return false;
      }
    }
    return true;
  }

  const TeamsAndRunnersManagementWidget({
    super.key,
    required this.raceId,
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
      raceId: widget.raceId,
      showHeader: widget.showHeader ?? true,
      onBack: widget.onBack,
      onContentChanged: widget.onContentChanged,
      isViewMode: widget.isViewMode,
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
            color: AppColors.backgroundColor,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  // Make the column take up the full available height
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (controller.showHeader) ...[
                      createSheetHeader(
                        'Teams and Runners',
                        backArrow: true,
                        context: context,
                        onBack: widget.onBack,
                      ),
                    ],

                    if (!controller.isViewMode) ...[
                      _buildActionButtons(),
                      const SizedBox(height: 12),
                    ],
                    if (!controller.isLoading) ...[
                      _buildSearchSection(),
                      const SizedBox(height: 8),
                      const ListTitles(),
                      const SizedBox(height: 4),
                    ],
                    // Use Expanded to fill remaining space with top-aligned content
                    Expanded(
                      child: RunnersList(controller: controller),
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

  // UI Building Methods
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: SharedActionButton(
              text: 'Create Team',
              icon: Icons.group_add,
              onPressed: () => _controller.showCreateTeamSheet(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SharedActionButton(
              text: 'Import Teams',
              icon: Icons.content_copy,
              onPressed: () => _controller.showExistingTeamsBrowser(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return RunnerSearchBar(
      controller: _controller.searchController,
      searchAttribute: _controller.searchAttribute,
      onSearchChanged: () => _controller.filterRaceRunners(_controller.searchController.text),
      onAttributeChanged: (value) {
        setState(() {
          _controller.searchAttribute = value!;
          _controller.filterRaceRunners(_controller.searchController.text);
        });
      },
      onDeleteAll: _controller.isViewMode
          ? null
          : () => _controller.confirmDeleteAllRunners(context),
      isViewMode: _controller.isViewMode,
    );
  }
}
