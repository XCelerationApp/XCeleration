import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/database_helper.dart';

class ExistingTeamsBrowserDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableTeams;
  final int raceId;

  const ExistingTeamsBrowserDialog({
    super.key,
    required this.availableTeams,
    required this.raceId,
  });

  @override
  State<ExistingTeamsBrowserDialog> createState() =>
      _ExistingTeamsBrowserDialogState();
}

class _ExistingTeamsBrowserDialogState
    extends State<ExistingTeamsBrowserDialog> {
  final Map<int, bool> _selectedTeams = {};
  final Map<int, List<Runner>> _teamRunners = {};
  final Map<int, Set<int>> _selectedRunners = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamRunners();
  }

  Future<void> _loadTeamRunners() async {
    for (final team in widget.availableTeams) {
      final teamId = team['team_id'] as int;
      final runners = await DatabaseHelper.instance.getTeamRunners(teamId);
      _teamRunners[teamId] = runners;
      _selectedRunners[teamId] = <int>{};
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _toggleTeamSelection(int teamId) {
    setState(() {
      _selectedTeams[teamId] = !(_selectedTeams[teamId] ?? false);
      if (!_selectedTeams[teamId]!) {
        _selectedRunners[teamId]?.clear();
      }
    });
  }

  void _toggleRunnerSelection(int teamId, int runnerId) {
    setState(() {
      if (_selectedRunners[teamId]!.contains(runnerId)) {
        _selectedRunners[teamId]!.remove(runnerId);
      } else {
        _selectedRunners[teamId]!.add(runnerId);
      }
    });
  }

  void _selectAllRunnersForTeam(int teamId) {
    setState(() {
      _selectedRunners[teamId] =
          _teamRunners[teamId]!.map((runner) => runner.runnerId!).toSet();
    });
  }

  void _deselectAllRunnersForTeam(int teamId) {
    setState(() {
      _selectedRunners[teamId]?.clear();
    });
  }

  List<Map<String, dynamic>> _getSelectedTeamsData() {
    final result = <Map<String, dynamic>>[];

    for (final teamId in _selectedTeams.keys) {
      if (_selectedTeams[teamId] == true &&
          _selectedRunners[teamId]!.isNotEmpty) {
        result.add({
          'team_id': teamId,
          'selected_runners': _selectedRunners[teamId]!.toList(),
        });
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Teams from Other Races'),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              child: widget.availableTeams.isEmpty
                  ? const Center(
                      child: Text('No teams available from other races.'),
                    )
                  : ListView.builder(
                      itemCount: widget.availableTeams.length,
                      itemBuilder: (context, index) {
                        final team = widget.availableTeams[index];
                        final teamId = team['team_id'] as int;
                        final teamName = team['name'] as String;
                        final teamAbbreviation =
                            team['abbreviation'] as String?;
                        final teamColor =
                            Color(team['color'] as int? ?? 0xFF2196F3);
                        final runners = _teamRunners[teamId] ?? [];
                        final isTeamSelected = _selectedTeams[teamId] ?? false;
                        final selectedRunnerCount =
                            _selectedRunners[teamId]?.length ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            leading: Checkbox(
                              value: isTeamSelected,
                              onChanged: (_) => _toggleTeamSelection(teamId),
                            ),
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: teamColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(teamName)),
                                if (teamAbbreviation != null)
                                  Text(
                                    '($teamAbbreviation)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${runners.length} runners${selectedRunnerCount > 0 ? ', $selectedRunnerCount selected' : ''}',
                            ),
                            children: [
                              if (isTeamSelected) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _selectAllRunnersForTeam(teamId),
                                        child: const Text('Select All'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _deselectAllRunnersForTeam(teamId),
                                        child: const Text('Clear All'),
                                      ),
                                    ],
                                  ),
                                ),
                                ...runners.map((runner) {
                                  final isSelected = _selectedRunners[teamId]!
                                      .contains(runner.runnerId);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (_) => _toggleRunnerSelection(
                                        teamId, runner.runnerId!),
                                    title: Text(runner.name!),
                                    subtitle: Text(
                                        'Bib: ${runner.bibNumber!}, Grade: ${runner.grade!}'),
                                    dense: true,
                                  );
                                }),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _getSelectedTeamsData().isNotEmpty
              ? () => Navigator.of(context).pop(_getSelectedTeamsData())
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Add ${_getSelectedTeamsData().length} Team(s)',
          ),
        ),
      ],
    );
  }
}
