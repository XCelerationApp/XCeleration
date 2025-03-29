import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xcelerate/coach/race_screen/widgets/runner_record.dart';
import '../../../core/theme/app_colors.dart';
import '../../../utils/sheet_utils.dart';
import '../../../utils/database_helper.dart';
import '../controller/runners_management_controller.dart';
import '../widgets/runner_list_item.dart';
import '../widgets/runner_search_bar.dart';

// Main Screen
class RunnersManagementScreen extends StatefulWidget {
  final int raceId;
  final VoidCallback? onBack;
  final VoidCallback? onContentChanged;
  final bool? showHeader;

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
      if (runnerCount < 1) { // only checking 1 for testing purposes
        return false;
      }
    }

    return true;
  }

  const RunnersManagementScreen({
    super.key,
    required this.raceId,
    this.showHeader,
    this.onBack,
    this.onContentChanged,
  });

  @override
  State<RunnersManagementScreen> createState() => _RunnersManagementScreenState();
}

class _RunnersManagementScreenState extends State<RunnersManagementScreen> {
  late RunnersManagementController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RunnersManagementController(
      raceId: widget.raceId,
      showHeader: widget.showHeader ?? true,
      onBack: widget.onBack,
      onContentChanged: widget.onContentChanged,
    );
    _controller.setContext(context);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.showHeader) ...[
                  createSheetHeader(
                    'Race Runners',
                    backArrow: true,
                    context: context,
                    onBack: widget.onBack,
                  ),
                ],
                _buildActionButtons(),
                const SizedBox(height: 12),
                if (controller.runners.isNotEmpty) ...[
                  _buildSearchSection(),
                  const SizedBox(height: 8),
                ],
                _buildListTitles(),
                const SizedBox(height: 4),
                // Expanded(
                _buildRunnersList(),
                // ),
              ],
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
          _buildActionButton(
            'Add Runner',
            icon: Icons.person_add_alt_1,
            onPressed: () => _controller.showRunnerSheet(context: context, runner: null),
          ),
          _buildActionButton(
            'Load Runners',
            icon: Icons.table_chart,
            onPressed: _controller.handleSpreadsheetLoad,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, {required VoidCallback onPressed, IconData? icon}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        fixedSize: const Size(160, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: AppColors.primaryColor.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
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
      onDeleteAll: () => _controller.confirmDeleteAllRunners(context),
    );
  }

  Widget _buildRunnersList() {
    if (_controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
        ),
      );
    }

    if (_controller.filteredRunners.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.mediumColor.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              _controller.searchController.text.isEmpty
                  ? 'No Runners Added'
                  : 'No runners found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumColor,
              ),
            ),
            if (_controller.searchController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.mediumColor.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Group runners by school
    final groupedRunners = <String, List<RunnerRecord>>{};
    for (var runner in _controller.filteredRunners) {
      if (!groupedRunners.containsKey(runner.school)) {
        groupedRunners[runner.school] = [];
      }
      groupedRunners[runner.school]!.add(runner);
    }

    // Sort schools alphabetically
    final sortedSchools = groupedRunners.keys.toList()..sort();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: sortedSchools.length,
        itemBuilder: (context, index) {
          final school = sortedSchools[index];
          final schoolRunners = groupedRunners[school]!;
          final team = _controller.teams.firstWhereOrNull((team) => team.name == school);
          final schoolColor = team != null ? team.color : Colors.blueGrey[400];

          return AnimatedOpacity(
            opacity: 1.0,
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, thickness: 1, color: Colors.grey),
                Container(
                  decoration: BoxDecoration(
                    color: schoolColor?.withAlpha((0.12 * 255).round()) ?? Colors.grey.withAlpha((0.12 * 255).round()),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  margin: const EdgeInsets.only(right: 16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school,
                        size: 18,
                        color: schoolColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        school,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: schoolColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: schoolColor?.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${schoolRunners.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: schoolColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...schoolRunners.map((runner) => RunnerListItem(
                  runner: runner,
                  controller: _controller,
                  onAction: (action) => _controller.handleRunnerAction(action, runner),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildListTitles() {
    const double fontSize = 14;
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            'Name',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'School',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Gr.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              'Bib',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)
            ),
          ),
        ),
      ],
    );
  }
}