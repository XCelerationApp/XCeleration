import 'package:flutter/material.dart';
import '../../../core/components/runner_form_validator.dart';
import '../../../core/components/button_components.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';

/// Simplified create-runner form for the prototype.
/// Collects name, bib, team, and grade; validates uniqueness against known bibs.
class CreateRunnerSheet extends StatefulWidget {
  const CreateRunnerSheet({
    super.key,
    required this.allKnownBibs,
    required this.teams,
    required this.onCreated,
    this.forbiddenBib,
    this.autoBib,
    this.initialName = '',
    this.savedBibOwners = const {},
  });

  /// All bib numbers already in use — new bib must not be in this set.
  final Set<String> allKnownBibs;

  /// Team names available for selection.
  final List<String> teams;

  /// Called with confirmed data when the form is submitted.
  final void Function(String name, String bibNumber, String team, int grade)
  onCreated;

  /// Bib that cannot be reused (set for duplicate step2).
  final String? forbiddenBib;

  /// The bib to give the runner, such as the unknown bib recorded at the
  /// finish. Shown filled in, with a pencil to change it.
  final String? autoBib;

  /// The name typed into Find Runner, so it need not be typed again.
  final String initialName;

  /// Bibs held by runners saved on this phone who are not in this race, with
  /// each one's name. A bib belongs to one saved runner at most, so one of
  /// these can only go to that runner: adding them enters them in the race.
  final Map<String, String> savedBibOwners;

  @override
  State<CreateRunnerSheet> createState() => _CreateRunnerSheetState();
}

class _CreateRunnerSheetState extends State<CreateRunnerSheet> {
  final _nameController = TextEditingController();
  final _bibController = TextEditingController();

  String? _nameError;
  String? _bibError;
  String? _selectedTeam;
  int? _selectedGrade;

  /// Whether the filled-in bib has been opened for changing with its pencil.
  bool _editingBib = false;

  static const List<int> _grades = [9, 10, 11, 12];

  @override
  void initState() {
    super.initState();
    _bibController.text = widget.autoBib ?? '';
    // The recorded bib is a saved runner's: most likely it is them, just
    // not entered in this race.
    _nameController.text = widget.initialName.isEmpty
        ? widget.savedBibOwners[widget.autoBib] ?? ''
        : widget.initialName;
  }

  String get _bib =>
      (_bibLocked ? widget.autoBib! : _bibController.text).trim();

  /// Why the bib can't go to the name typed: it is already a saved runner's,
  /// someone else's. Null when it is free, or it is that runner.
  String? get _ownerError {
    final owner = widget.savedBibOwners[_bib];
    if (owner == null) return null;
    String plain(String s) => s.trim().toLowerCase();
    if (plain(owner) == plain(_nameController.text)) return null;
    return 'Bib #$_bib is already $owner\'s, saved from another race. '
        'Type $owner to add them, or change the bib.';
  }

  bool get _bibLocked => widget.autoBib != null && !_editingBib;

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
    // The same format rule as everywhere else a bib is typed.
    final formatError = RunnerFormValidator.validateBibFormat(trimmed);
    if (formatError != null) {
      setState(() => _bibError = formatError);
      return;
    }
    if (widget.forbiddenBib != null && trimmed == widget.forbiddenBib) {
      setState(
        () => _bibError =
            'Bib #${widget.forbiddenBib} is the duplicate — choose a new number',
      );
      return;
    }
    if (widget.allKnownBibs.contains(trimmed)) {
      setState(() => _bibError = 'Bib #$trimmed is already in use');
      return;
    }
    setState(() => _bibError = null);
  }

  bool get _canSubmit {
    final nameOk = _nameController.text.trim().isNotEmpty && _nameError == null;
    final bibOk = _bibLocked ||
        (_bibController.text.trim().isNotEmpty && _bibError == null);
    return nameOk &&
        bibOk &&
        _ownerError == null &&
        _selectedTeam != null &&
        _selectedGrade != null;
  }

  void _submit() {
    _validateName(_nameController.text);
    if (!_bibLocked) _validateBib(_bibController.text);
    if (!_canSubmit) return;
    widget.onCreated(
      _nameController.text.trim(),
      _bibLocked ? widget.autoBib! : _bibController.text.trim(),
      _selectedTeam!,
      _selectedGrade!,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls because it is filled in with the keyboard up, which leaves less
    // than half the screen on a smaller phone.
    return SingleChildScrollView(
      child: Column(
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
          if (_bibLocked)
            _AutoBibDisplay(
              bibNumber: widget.autoBib!,
              onEdit: () => setState(() {
                _editingBib = true;
                _validateBib(_bibController.text);
              }),
            )
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
          if (_ownerError case final error?) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              error,
              key: const ValueKey('bib_owner_error'),
              style: AppTypography.caption.copyWith(color: AppColors.redColor),
            ),
          ],
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
      ),
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
            fillColor: AppColors.lightColor.withValues(
              alpha: AppOpacity.medium,
            ),
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
  const _AutoBibDisplay({required this.bibNumber, required this.onEdit});

  final String bibNumber;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bib number', style: AppTypography.smallBodySemibold),
        const SizedBox(height: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.lightColor.withValues(alpha: AppOpacity.medium),
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('#$bibNumber', style: AppTypography.bodySemibold),
                    Text(
                      'Tap the pencil to change it',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.mediumColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const ValueKey('edit_new_runner_bib'),
                tooltip: 'Change bib',
                icon: const Icon(Icons.edit,
                    color: AppColors.primaryColor, size: 20),
                onPressed: onEdit,
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
          // Rounded and white, like the app's other menus.
          child: DropdownButton<T>(
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            elevation: 4,
            menuMaxHeight: 360,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.mediumColor),
            value: value,
            onChanged: onChanged,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: AppTypography.bodyRegular.copyWith(
              color: AppColors.darkColor,
            ),
            hint: Text(
              hint,
              style: AppTypography.bodyRegular.copyWith(
                color: AppColors.mediumColor.withValues(
                  alpha: AppOpacity.solid,
                ),
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
