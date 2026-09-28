import 'package:flutter/material.dart';
import 'package:xceleration/core/components/runner_search_bar.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';

/// The runners the Bib Recorder has for the race, searchable by name, bib or
/// team and filterable by team, so a volunteer can find who a bib belongs to.
class RunnersLoadedSheet extends StatefulWidget {
  final List<BibDatum> runners;

  const RunnersLoadedSheet({super.key, required this.runners});

  @override
  State<RunnersLoadedSheet> createState() => _RunnersLoadedSheetState();
}

class _RunnersLoadedSheetState extends State<RunnersLoadedSheet> {
  final _search = TextEditingController();

  /// The team shown, or null for every team.
  String? _team;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _teams => {
        for (final r in widget.runners)
          if ((r.teamAbbreviation ?? '').isNotEmpty) r.teamAbbreviation!,
      }.toList()
        ..sort();

  /// In bib order, by number: 2 before 10.
  late final List<BibDatum> _byBib = [...widget.runners]..sort((a, b) {
      final na = int.tryParse(a.bib), nb = int.tryParse(b.bib);
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
      return a.bib.compareTo(b.bib);
    });

  List<BibDatum> get _shown {
    final query = _search.text.trim().toLowerCase();
    return [
      for (final r in _byBib)
        if ((_team == null || r.teamAbbreviation == _team) &&
            (query.isEmpty ||
                (r.name ?? '').toLowerCase().contains(query) ||
                r.bib.startsWith(query) ||
                (r.teamAbbreviation ?? '').toLowerCase().contains(query)))
          r,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final teams = _teams;
    final shown = _shown;
    final total = widget.runners.length;
    // A long list keeps its height as it is filtered, so the search box does
    // not jump about while typing.
    final maxHeight = MediaQuery.of(context).size.height * 0.5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RunnerSearchBar(
          controller: _search,
          onSearchChanged: () => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                shown.length == total
                    ? '$total runners'
                    : '${shown.length} of $total runners',
                style: AppTypography.smallBodyRegular
                    .copyWith(color: AppColors.mediumColor),
              ),
            ),
            if (teams.length > 1)
              _TeamFilter(
                teams: teams,
                runners: widget.runners,
                selected: _team,
                onSelected: (team) => setState(() => _team = team),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const _TableHeader(),
        Flexible(
          child: SizedBox(
            height: total > 8 ? maxHeight : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: shown.isEmpty
                  ? const _NoMatch()
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: shown.length,
                      itemBuilder: (context, index) =>
                          _RunnerRow(runner: shown[index]),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single "Team" button that opens a list of the teams, so any number of
/// teams fits beside the count.
class _TeamFilter extends StatelessWidget {
  const _TeamFilter({
    required this.teams,
    required this.runners,
    required this.selected,
    required this.onSelected,
  });

  final List<String> teams;
  final List<BibDatum> runners;
  final String? selected;
  final ValueChanged<String?> onSelected;

  /// Stands for "All teams" in the menu: an item whose value is null would
  /// count as closing the menu without choosing.
  static const _all = '';

  Color? _colorOf(String team) =>
      runners.where((r) => r.teamAbbreviation == team).firstOrNull?.teamColor;

  Widget _label(String? team, {bool bold = false}) {
    final color = team == null ? null : _colorOf(team);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (color != null) ...[
          CircleAvatar(backgroundColor: color, radius: 5),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          team ?? 'All teams',
          style: bold ? AppTypography.bodySemibold : AppTypography.bodyRegular,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const ValueKey('team_filter'),
      tooltip: 'Filter by team',
      initialValue: selected ?? _all,
      onSelected: (value) => onSelected(value == _all ? null : value),
      itemBuilder: (context) => [
        for (final team in [null, ...teams])
          PopupMenuItem<String>(
            key: ValueKey('team_filter_${team ?? 'all'}'),
            value: team ?? _all,
            child: Row(
              children: [
                SizedBox(
                  width: AppSpacing.xl,
                  child: selected == team
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                _label(team),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _label(selected, bold: true),
            const Icon(Icons.arrow_drop_down, color: AppColors.mediumColor),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySemibold;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Name', style: style)),
          Expanded(flex: 2, child: Text('Team', style: style)),
          Expanded(child: Text('Gr.', style: style)),
          Expanded(child: Text('Bib', style: style)),
        ],
      ),
    );
  }
}

class _RunnerRow extends StatelessWidget {
  const _RunnerRow({required this.runner});

  final BibDatum runner;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(runner.name ?? '', style: AppTypography.bodyRegular)),
          Expanded(
              flex: 2,
              child: Text(runner.teamAbbreviation ?? '',
                  style: AppTypography.bodyRegular)),
          Expanded(
              child:
                  Text(runner.grade ?? '', style: AppTypography.bodyRegular)),
          Expanded(
              child: Text(runner.bib, style: AppTypography.bodySemibold)),
        ],
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Text(
          'No runners match',
          style: AppTypography.bodyRegular
              .copyWith(color: AppColors.mediumColor),
        ),
      ),
    );
  }
}
