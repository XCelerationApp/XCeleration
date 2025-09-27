import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/typography.dart';

class ImportedRunnersSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>>
      importedRunners; // expects keys: name, grade, bib

  const ImportedRunnersSelectionSheet({
    super.key,
    required this.importedRunners,
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

  List<int> _visibleIndices() {
    final indices = <int>[];
    for (int i = 0; i < widget.importedRunners.length; i++) {
      final row = widget.importedRunners[i];
      if (_rowMatchesGender(row)) indices.add(i);
    }
    return indices;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndices();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(value: _selectAll, onChanged: _toggleAll),
              const Text('Select All', style: AppTypography.bodyMedium),
              const Spacer(),
              Builder(builder: (_) {
                final selectedVisible =
                    visible.where((i) => _selected[i]).length;
                return Text(
                  '$selectedVisible selected',
                  style: const TextStyle(color: Colors.black54),
                );
              }),
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
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visible.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final actualIndex = visible[index];
                  final row = widget.importedRunners[actualIndex];
                  final name = (row['name'] ?? '').toString();
                  final grade = (row['grade'] ?? '').toString();
                  final bib = (row['bib'] ?? '').toString();
                  final gender = (row['gender'] ?? '').toString();
                  return CheckboxListTile(
                    value: _selected[actualIndex],
                    onChanged: (v) => setState(() {
                      _selected[actualIndex] = v ?? false;
                      _selectAll = visible.every((i) => _selected[i]);
                    }),
                    title: Text(name, style: AppTypography.bodyMedium),
                    subtitle: Text(
                      gender.isNotEmpty
                          ? 'Grade $grade  •  Bib $bib  •  $gender'
                          : 'Grade $grade  •  Bib $bib',
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
                    final selected = <Map<String, dynamic>>[];
                    for (int i = 0; i < widget.importedRunners.length; i++) {
                      if (_selected[i] &&
                          _rowMatchesGender(widget.importedRunners[i])) {
                        selected.add(widget.importedRunners[i]);
                      }
                    }
                    Navigator.of(context).pop(selected);
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
