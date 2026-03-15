import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/components/runner_form_validator.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_opacity.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/grade_utils.dart';
import '../../../shared/models/database/race_runner.dart';
import '../../../shared/models/database/runner.dart';
import '../../../shared/models/database/team.dart';

class AddRunnersToTeamSheet extends StatefulWidget {
  const AddRunnersToTeamSheet({
    super.key,
    required this.team,
    required this.raceId,
    required this.onSubmit,
    required this.getRunnerByBib,
  });

  final Team team;
  final int raceId;
  final Future<void> Function(RaceRunner raceRunner) onSubmit;
  final Future<Runner?> Function(String bib) getRunnerByBib;

  @override
  State<AddRunnersToTeamSheet> createState() => _AddRunnersToTeamSheetState();
}

class _AddRunnersToTeamSheetState extends State<AddRunnersToTeamSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bibController = TextEditingController();

  int? _selectedGrade;
  String? _bibError;
  bool _isSubmitting = false;

  Timer? _bibDebounce;

  @override
  void dispose() {
    _nameController.dispose();
    _bibController.dispose();
    _bibDebounce?.cancel();
    super.dispose();
  }

  void _onBibChanged(String value) {
    _bibDebounce?.cancel();
    final formatError = RunnerFormValidator.validateBibFormat(value);
    if (formatError != null) {
      setState(() => _bibError = null);
      return;
    }
    _bibDebounce = Timer(const Duration(milliseconds: 400), () async {
      final existing = await widget.getRunnerByBib(value.trim());
      if (!mounted) return;
      setState(() {
        _bibError = existing != null
            ? 'Bib ${value.trim()} is already taken by ${existing.name ?? "another runner"}'
            : null;
      });
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a grade',
            style: AppTypography.smallBodyRegular,
          ),
          backgroundColor: AppColors.redColor,
        ),
      );
      return;
    }
    if (_bibError != null) return;

    setState(() => _isSubmitting = true);
    try {
      final raceRunner = RaceRunner(
        raceId: widget.raceId,
        runner: Runner(
          name: _nameController.text.trim(),
          bibNumber: _bibController.text.trim(),
          grade: _selectedGrade,
        ),
        team: widget.team,
      );
      await widget.onSubmit(raceRunner);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel('Name'),
          const SizedBox(height: AppSpacing.xs),
          _NameField(controller: _nameController),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Bib #'),
          const SizedBox(height: AppSpacing.xs),
          _BibField(
            controller: _bibController,
            asyncError: _bibError,
            onChanged: _onBibChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          const _FieldLabel('Grade'),
          const SizedBox(height: AppSpacing.xs),
          _GradeSelector(
            selected: _selectedGrade,
            onSelected: (grade) => setState(() => _selectedGrade = grade),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SubmitButton(
            isSubmitting: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.captionBold.copyWith(
        color: AppColors.mediumColor,
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: "Runner's full name",
        hintStyle: AppTypography.smallBodyRegular.copyWith(
          color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
        ),
        filled: true,
        fillColor: AppColors.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.redColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.redColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      style: AppTypography.smallBodyRegular.copyWith(
        color: AppColors.darkColor,
      ),
      validator: (v) => RunnerFormValidator.validateName(v ?? ''),
    );
  }
}

class _BibField extends StatelessWidget {
  const _BibField({
    required this.controller,
    required this.asyncError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? asyncError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'e.g. 104',
        hintStyle: AppTypography.smallBodyRegular.copyWith(
          color: AppColors.mediumColor.withValues(alpha: AppOpacity.solid),
        ),
        errorText: asyncError,
        filled: true,
        fillColor: AppColors.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.redColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          borderSide: const BorderSide(color: AppColors.redColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
      style: AppTypography.smallBodyRegular.copyWith(
        color: AppColors.darkColor,
      ),
      validator: (v) => RunnerFormValidator.validateBibFormat(v ?? ''),
    );
  }
}

class _GradeSelector extends StatelessWidget {
  const _GradeSelector({
    required this.selected,
    required this.onSelected,
  });

  final int? selected;
  final ValueChanged<int> onSelected;

  static const _grades = [9, 10, 11, 12];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _grades.map((grade) {
        final isSelected = selected == grade;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: grade != 12 ? AppSpacing.sm : 0,
            ),
            child: _GradePill(
              label: gradeLabel(grade),
              isSelected: isSelected,
              onTap: () => onSelected(grade),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: isSelected ? AppColors.primaryColor : AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: GestureDetector(
        onTap: isSubmitting ? null : onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: isSubmitting
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryColor, AppColors.primaryGradientEnd],
                  ),
            color: isSubmitting ? AppColors.lightColor : null,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
            boxShadow: isSubmitting
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: AppOpacity.strong),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.backgroundColor,
                      ),
                    ),
                  )
                : Text(
                    'Add Runner',
                    style: AppTypography.bodySemibold.copyWith(
                      color: AppColors.backgroundColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
