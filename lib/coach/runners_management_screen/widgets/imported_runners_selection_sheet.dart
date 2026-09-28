import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';
import '../services/roster_importer.dart';

class ImportedRunnersSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>>
  importedRunners; // expects keys: name, grade, bib

  /// Spreadsheet rows that could not be imported, with the reason.
  final List<String> skippedRows;

  const ImportedRunnersSelectionSheet({
    super.key,
    required this.importedRunners,
    this.skippedRows = const [],
  });

  @override
  State<ImportedRunnersSelectionSheet> createState() =>
      _ImportedRunnersSelectionSheetState();
}

class _ImportedRunnersSelectionSheetState
    extends State<ImportedRunnersSelectionSheet> {
  late List<bool> _selected;
  bool _selectAll = true;
  bool _showBoys = true;
  bool _showGirls = true;

  /// Whether each team becomes a boys' and a girls' team.
  bool _splitByGender = false;

  /// Teams the coach unticked: saved with their runners, but not added to
  /// this race.
  final Set<String> _leftOutOfRace = {};

  /// Offered when the rows name their teams and have both boys and girls.
  late final bool _canSplit =
      widget.importedRunners.any(
        (r) => ((r['team'] as String?)?.trim() ?? '').isNotEmpty,
      ) &&
      widget.importedRunners.any(
        (r) => '${r['gender']}'.toUpperCase() == 'M',
      ) &&
      widget.importedRunners.any((r) => '${r['gender']}'.toUpperCase() == 'F');

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.importedRunners.length, true);
  }

  void _toggleAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      final indices = _visibleIndices();
      for (final i in indices) {
        _selected[i] = _selectAll;
      }
    });
  }

  bool _rowMatchesGender(Map<String, dynamic> row) {
    final g = (row['gender'] ?? '').toString().toUpperCase();
    if (g == 'M') return _showBoys;
    if (g == 'F') return _showGirls;
    // If gender missing, show in both
    return true;
  }

  /// The ticked rows, split into boys' and girls' teams when asked.
  List<Map<String, dynamic>> _chosenRows() {
    final selected = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.importedRunners.length; i++) {
      if (_selected[i] && _rowMatchesGender(widget.importedRunners[i])) {
        selected.add(widget.importedRunners[i]);
      }
    }
    return _splitByGender
        ? RosterImporter.splitTeamsByGender(selected)
        : selected;
  }

  static String _teamOf(Map<String, dynamic> row) =>
      (row['team'] as String?)?.trim() ?? '';

  /// The teams the chosen rows go on, in the order they first appear.
  List<String> _teams(List<Map<String, dynamic>> rows) => [
    ...{
      for (final row in rows)
        if (_teamOf(row).isNotEmpty) _teamOf(row),
    },
  ];

  /// Lets the coach add only some of the teams to this race, such as just
  /// the girls. Every team is saved, ready for another race.
  Widget _buildRaceTeams(List<String> teams) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add to this race', style: AppTypography.bodySemibold),
          const SizedBox(height: 2),
          Text(
            'Every team is saved. Only the ticked teams join this race.',
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          const SizedBox(height: 8),
          // Many teams scroll here, so the runner list keeps its room.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 112),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final team in teams)
                    FilterChip(
                      key: ValueKey('race_team_$team'),
                      label: Text(team),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selected: !_leftOutOfRace.contains(team),
                      onSelected: (inRace) => setState(
                        () => inRace
                            ? _leftOutOfRace.remove(team)
                            : _leftOutOfRace.add(team),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _visibleIndices() {
    final indices = <int>[];
    for (int i = 0; i < widget.importedRunners.length; i++) {
      final row = widget.importedRunners[i];
      if (_rowMatchesGender(row)) indices.add(i);
    }
    return indices;
  }

  /// Says which spreadsheet rows were left out, so a runner missing from the
  /// list isn't a surprise on race day.
  Widget _buildSkippedRows() {
    final count = widget.skippedRows.length;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.primaryColor,
      ),
      title: Text(
        '$count ${count == 1 ? 'row was' : 'rows were'} not imported',
        style: AppTypography.bodyMedium,
      ),
      subtitle: const Text('Tap to see why'),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final row in widget.skippedRows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    row,
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndices();
    final teams = _teams(_chosenRows());
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.skippedRows.isNotEmpty) _buildSkippedRows(),
          Row(
            children: [
              Checkbox(value: _selectAll, onChanged: _toggleAll),
              const Text('Select All', style: AppTypography.bodyMedium),
              const Spacer(),
              Builder(
                builder: (_) {
                  final selectedVisible = visible
                      .where((i) => _selected[i])
                      .length;
                  return Text(
                    '$selectedVisible selected',
                    style: const TextStyle(color: Colors.black54),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _showBoys,
                onChanged: (v) => setState(() => _showBoys = v ?? true),
              ),
              const Text('Boys', style: AppTypography.bodyMedium),
              const SizedBox(width: 16),
              Checkbox(
                value: _showGirls,
                onChanged: (v) => setState(() => _showGirls = v ?? true),
              ),
              const Text('Girls', style: AppTypography.bodyMedium),
            ],
          ),
          if (_canSplit)
            CheckboxListTile(
              key: const ValueKey('split_boys_girls'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _splitByGender,
              onChanged: (v) => setState(() {
                _splitByGender = v ?? false;
                // The team names change, so start with every team ticked.
                _leftOutOfRace.clear();
              }),
              title: const Text(
                'Separate boys\' and girls\' teams',
                style: AppTypography.bodyMedium,
              ),
              subtitle: const Text(
                'e.g. "Archie Williams - Boys" and '
                '"Archie Williams - Girls"',
              ),
            ),
          if (teams.length > 1) _buildRaceTeams(teams),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                // The buttons below it, not the list, sit by the home bar.
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final actualIndex = visible[index];
                  final row = widget.importedRunners[actualIndex];
                  final name = (row['name'] ?? '').toString();
                  final grade = (row['grade'] ?? '').toString();
                  final bib = (row['bib'] ?? '').toString();
                  final gender = (row['gender'] ?? '').toString();
                  final team = (row['team'] ?? '').toString();
                  return CheckboxListTile(
                    value: _selected[actualIndex],
                    onChanged: (v) => setState(() {
                      _selected[actualIndex] = v ?? false;
                      _selectAll = visible.every((i) => _selected[i]);
                    }),
                    title: Text(name, style: AppTypography.bodyMedium),
                    subtitle: Text(
                      [
                        'Grade $grade',
                        'Bib $bib',
                        if (gender.isNotEmpty) gender,
                        if (team.isNotEmpty) team,
                      ].join('  •  '),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop([
                      for (final row in _chosenRows())
                        _leftOutOfRace.contains(_teamOf(row))
                            ? {...row, 'inRace': false}
                            : row,
                    ]);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add Selected'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
