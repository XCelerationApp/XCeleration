import 'package:flutter/material.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Simplified create-runner form for the prototype.
/// Collects name, bib, team, and grade; validates uniqueness against known bibs.
class MockCreateRunnerSheet extends StatefulWidget {
  const MockCreateRunnerSheet({
    super.key,
    required this.allKnownBibs,
    required this.teams,
    required this.onCreated,
    this.forbiddenBib,
    this.autoBib,
  });

  /// All bib numbers already in use — new bib must not be in this set.
  final Set<int> allKnownBibs;

  /// Team names available for selection.
  final List<String> teams;

  /// Called with confirmed data when the form is submitted.
  final void Function(String name, int bibNumber, String team, int grade) onCreated;

  /// Bib that cannot be reused (set for duplicate step2).
  final int? forbiddenBib;

  /// When set, locks the bib field to this value and skips bib validation.
  final int? autoBib;

  @override
  State<MockCreateRunnerSheet> createState() => _MockCreateRunnerSheetState();
}

class _MockCreateRunnerSheetState extends State<MockCreateRunnerSheet> {
  final _nameController = TextEditingController();
  final _bibController = TextEditingController();

  String? _nameError;
  String? _bibError;
  String? _selectedTeam;
  int? _selectedGrade;

  static const List<int> _grades = [9, 10, 11, 12];

  @override
  void dispose() {
    _nameController.dispose();
    _bibController.dispose();
    super.dispose();
  }

  void _validateName(String value) {
    setState(() {
      _nameError = value.trim().isEmpty ? 'Name is required' : null;
    });
  }

  void _validateBib(String value) {
    final trimmed = value.trim();
    final parsed = int.tryParse(trimmed);
    if (trimmed.isEmpty) {
      setState(() => _bibError = 'Bib number is required');
      return;
    }
    if (parsed == null || parsed <= 0) {
      setState(() => _bibError = 'Enter a valid bib number');
      return;
    }
    if (widget.forbiddenBib != null && parsed == widget.forbiddenBib) {
      setState(() =>
          _bibError = 'Bib #${widget.forbiddenBib} is the duplicate — choose a new number');
      return;
    }
    if (widget.allKnownBibs.contains(parsed)) {
      setState(() => _bibError = 'Bib #$parsed is already in use');
      return;
    }
    setState(() => _bibError = null);
  }

  bool get _canSubmit {
    final nameOk = _nameController.text.trim().isNotEmpty && _nameError == null;
    final bibOk = widget.autoBib != null
        ? true
        : _bibController.text.trim().isNotEmpty && _bibError == null;
    return nameOk && bibOk && _selectedTeam != null && _selectedGrade != null;
  }

  void _submit() {
    _validateName(_nameController.text);
    if (widget.autoBib == null) _validateBib(_bibController.text);
    if (!_canSubmit) return;
    widget.onCreated(
      _nameController.text.trim(),
      widget.autoBib ?? int.parse(_bibController.text.trim()),
      _selectedTeam!,
      _selectedGrade!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormField(
          label: 'Runner name',
          hint: 'e.g. John Smith',
          controller: _nameController,
          error: _nameError,
          onChanged: _validateName,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (widget.autoBib != null)
          _AutoBibDisplay(bibNumber: widget.autoBib!)
        else
          _FormField(
            label: 'Bib number',
            hint: widget.forbiddenBib != null
                ? 'Not #${widget.forbiddenBib} — that bib is taken'
                : 'e.g. 421',
            controller: _bibController,
            error: _bibError,
            onChanged: _validateBib,
            keyboardType: TextInputType.number,
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _DropdownField<String>(
                label: 'Team',
                hint: 'Select team',
                value: _selectedTeam,
                items: widget.teams,
                itemLabel: (t) => t,
                onChanged: (t) => setState(() => _selectedTeam = t),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: _DropdownField<int>(
                label: 'Grade',
                hint: 'Grade',
                value: _selectedGrade,
                items: _grades,
                itemLabel: (g) => '${g}th',
                onChanged: (g) => setState(() => _selectedGrade = g),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FullWidthButton(
          text: 'Add Runner',
          onPressed: _canSubmit ? _submit : null,
          isEnabled: _canSubmit,
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.error,
    this.keyboardType,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.smallBodySemibold),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyRegular.copyWith(
              color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
            ),
            errorText: error,
            filled: true,
            fillColor: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppColors.primaryColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppColors.redColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoBibDisplay extends StatelessWidget {
  const _AutoBibDisplay({required this.bibNumber});

  final int bibNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bib number', style: AppTypography.smallBodySemibold),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Row(
            children: [
              Text('#$bibNumber', style: AppTypography.bodySemibold),
              const Spacer(),
              Text(
                'auto-assigned',
                style: AppTypography.caption.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.smallBodySemibold),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: DropdownButton<T>(
            value: value,
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: AppTypography.bodyRegular.copyWith(color: AppColors.darkColor),
            hint: Text(
              hint,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), style: AppTypography.bodyRegular),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
