import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/shared/models/database/runner.dart';
import 'package:xceleration/shared/models/database/team.dart';

class ExistingTeamsBrowserSheet extends StatefulWidget {
  // Map of teams (from other races) to their runners
  final Map<Team, List<Runner>> availableTeams;
  final int raceId;

  const ExistingTeamsBrowserSheet({
    super.key,
    required this.availableTeams,
    required this.raceId,
  });

  @override
  State<ExistingTeamsBrowserSheet> createState() =>
      _ExistingTeamsBrowserSheetState();
}

class _ExistingTeamsBrowserSheetState extends State<ExistingTeamsBrowserSheet> {
  final Map<int, bool> _selectedTeams = {};
  final Map<int, List<Runner>> _teamRunners = {};
  final Map<int, Set<int>> _selectedRunners = {};
  late final List<Team> _teams;

  @override
  void initState() {
    super.initState();
    // Initialize from the provided map (no DB calls here)
    _teams = widget.availableTeams.keys.toList();
    for (final team in _teams) {
      final runners = widget.availableTeams[team] ?? <Runner>[];
      _teamRunners[team.teamId!] = runners;
      _selectedRunners[team.teamId!] = <int>{};
    }
  }

  Map<Team, List<Runner>> _getSelectedTeamsMap() {
    final Map<Team, List<Runner>> selected = {};
    for (final team in _teams) {
      final teamId = team.teamId!;
      if (_selectedTeams[teamId] == true) {
        final selectedIds = _selectedRunners[teamId] ?? <int>{};
        if (selectedIds.isEmpty) {
          // Allow adding teams with no runners
          selected[team] = <Runner>[];
        } else {
          final runners = _teamRunners[teamId]!
              .where(
                  (r) => r.runnerId != null && selectedIds.contains(r.runnerId))
              .toList();
          selected[team] = runners;
        }
      }
    }
    return selected;
  }

  void _toggleTeamSelection(int teamId) {
    setState(() {
      _selectedTeams[teamId] = !(_selectedTeams[teamId] ?? false);
      if (!(_selectedTeams[teamId] ?? false)) {
        _selectedRunners[teamId]?.clear();
      } else {
        // Default to selecting all runners when a team is chosen
        _selectedRunners[teamId] = _teamRunners[teamId]!
            .where((r) => r.runnerId != null)
            .map((r) => r.runnerId!)
            .toSet();
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

  @override
  Widget build(BuildContext context) {
    if (widget.availableTeams.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'You have no teams from other races to import',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _teams.length,
            itemBuilder: (context, index) {
              final team = _teams[index];
              final teamId = team.teamId!;
              final teamName = team.name ?? '';
              // final teamAbbreviation = team.abbreviation; // no longer displayed
              final teamColor = team.color ?? Colors.black;
              final runners = _teamRunners[teamId] ?? [];
              final isTeamSelected = _selectedTeams[teamId] ?? false;
              final selectedRunnerCount = _selectedRunners[teamId]?.length ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: teamColor, width: 1.5),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: Checkbox(
                    value: isTeamSelected,
                    onChanged: (_) => _toggleTeamSelection(teamId),
                  ),
                  title: Text(teamName),
                  subtitle: Text(
                    '${runners.length} runner${runners.length == 1 ? '' : 's'}${selectedRunnerCount > 0 ? ', $selectedRunnerCount selected' : ''}',
                  ),
                  children: [
                    if (runners.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No runners found for this team',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ...runners.map((runner) {
                      final rid = runner.runnerId!;
                      final isSelected =
                          _selectedRunners[teamId]!.contains(rid);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleRunnerSelection(teamId, rid),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(runner.name ?? ''),
                        subtitle: Text(
                            'Bib: ${runner.bibNumber ?? '-'}  •  Grade: ${runner.grade ?? '-'}'),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Builder(builder: (context) {
                final selectedCount =
                    _selectedTeams.values.where((v) => v == true).length;
                final isEnabled = selectedCount > 0;
                return ElevatedButton(
                  onPressed: isEnabled
                      ? () => Navigator.of(context).pop(_getSelectedTeamsMap())
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                      'Add $selectedCount Team${selectedCount == 1 ? '' : 's'}'),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}
