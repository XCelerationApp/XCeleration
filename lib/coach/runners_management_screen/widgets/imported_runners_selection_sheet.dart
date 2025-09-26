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

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.importedRunners.length, true);
  }

  void _toggleAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      for (int i = 0; i < _selected.length; i++) {
        _selected[i] = _selectAll;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                '${_selected.where((s) => s).length} selected',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.importedRunners.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = widget.importedRunners[index];
                  final name = (row['name'] ?? '').toString();
                  final grade = (row['grade'] ?? '').toString();
                  final bib = (row['bib'] ?? '').toString();
                  return CheckboxListTile(
                    value: _selected[index],
                    onChanged: (v) => setState(() {
                      _selected[index] = v ?? false;
                      _selectAll = _selected.every((s) => s);
                    }),
                    title: Text(name, style: AppTypography.bodyMedium),
                    subtitle: Text('Grade $grade  •  Bib $bib'),
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
                      if (_selected[i]) selected.add(widget.importedRunners[i]);
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
