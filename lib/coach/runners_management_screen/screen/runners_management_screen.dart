import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/runners_management_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/button_components.dart';
import '../../../core/utils/sheet_utils.dart';
import '../../../core/utils/database_helper.dart';
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
    final race = await DatabaseHelper.instance.getRaceById(raceId);
    final runners = await DatabaseHelper.instance.getRaceRunners(raceId);
    // Check if we have any runners at all
    if (runners.isEmpty) {
      return false;
    }

    // Check if each team has at least 5 runners (minimum for a race)
    final teamRunnerCounts = <String, int>{};
    for (final runner in runners) {
      final team = runner.school;
      teamRunnerCounts[team] = (teamRunnerCounts[team] ?? 0) + 1;
    }

    // Verify each team in the race has enough runners
    for (final teamName in race!.teams) {
      final runnerCount = teamRunnerCounts[teamName] ?? 0;
      if (runnerCount < 1) {
        // only checking 1 for testing purposes
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
                    if (controller.runners.isNotEmpty) ...[
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SharedActionButton(
            text: 'Add Runner',
            icon: Icons.person_add_alt_1,
            onPressed: () =>
                _controller.showRunnerSheet(context: context, runner: null),
          ),
          SharedActionButton(
            text: 'Load Runners',
            icon: Icons.table_chart,
            onPressed: () => _controller.handleSpreadsheetLoad(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return RunnerSearchBar(
      controller: _controller.searchController,
      searchAttribute: _controller.searchAttribute,
      onSearchChanged: _controller.filterRunners,
      onAttributeChanged: (value) {
        setState(() {
          _controller.searchAttribute = value!;
          _controller.filterRunners(_controller.searchController.text);
        });
      },
      onDeleteAll: _controller.isViewMode
          ? null
          : () => _controller.confirmDeleteAllRunners(context),
      isViewMode: _controller.isViewMode,
    );
  }
}
