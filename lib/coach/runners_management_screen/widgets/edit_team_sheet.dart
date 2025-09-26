import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:xceleration/shared/models/database/team.dart';
import 'package:xceleration/core/components/button_components.dart';
import 'package:xceleration/core/components/textfield_utils.dart'
    as textfield_utils;
import 'package:xceleration/core/theme/app_colors.dart';

class EditTeamSheet extends StatefulWidget {
  final Team team;
  final ValueChanged<Team> onSave;

  const EditTeamSheet({super.key, required this.team, required this.onSave});

  @override
  State<EditTeamSheet> createState() => _EditTeamSheetState();
}

class _EditTeamSheetState extends State<EditTeamSheet> {
  late TextEditingController _nameController;
  late Color _color;
  late final String _originalName;
  late final Color _originalColor;

  @override
  void initState() {
    super.initState();
    _originalName = widget.team.name ?? '';
    _originalColor = widget.team.color ?? const Color(0xFF2196F3);
    _nameController = TextEditingController(text: _originalName);
    _nameController.addListener(() => setState(() {}));
    _color = _originalColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.amber.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are editing the global team. Changes affect all races.',
                  style: TextStyle(fontSize: 13, color: Colors.amber.shade600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        textfield_utils.buildInputRow(
          label: 'Name',
          inputWidget: textfield_utils.buildTextField(
            context: context,
            controller: _nameController,
            hint: 'Team name',
            onChanged: (_) => setState(() {}),
            setSheetState: setState,
          ),
        ),
        const SizedBox(height: 12),
        textfield_utils.buildInputRow(
          label: 'Color',
          inputWidget: Row(
            children: [
              GestureDetector(
                onTap: _showColorPicker,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showColorPicker,
                  icon: const Icon(Icons.color_lens_outlined, size: 18),
                  label: const Text('Change Color'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    foregroundColor: AppColors.primaryColor,
                    side: BorderSide(color: AppColors.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FullWidthButton(
          text: 'Save',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          borderRadius: 8,
          isEnabled: _canSave,
          onPressed: () {
            final updated = widget.team.copyWith(
              name: _nameController.text.trim(),
              color: _color,
            );
            widget.onSave(updated);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pick Team Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _color,
              onColorChanged: (c) => setState(() => _color = c),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            )
          ],
        );
      },
    );
  }

  bool get _canSave {
    final currentName = _nameController.text.trim();
    final changed = currentName != _originalName.trim() ||
        _color.toARGB32() != _originalColor.toARGB32();
    return changed && currentName.isNotEmpty;
  }
}
