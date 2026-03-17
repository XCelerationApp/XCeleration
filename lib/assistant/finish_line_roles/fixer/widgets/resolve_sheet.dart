import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/ordinal.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Bottom sheet for resolving a flagged [FixerEntry].
///
/// Presents two resolution paths:
///   1. Search by name → pick from top-5 fuzzy matches
///   2. Create new runner → fill name/bib form and add to roster
///
/// A "Leave for coach" option closes the sheet without resolving.
class ResolveSheet extends StatefulWidget {
  const ResolveSheet({
    super.key,
    required this.entry,
    required this.controller,
  });

  final FixerEntry entry;
  final FixerController controller;

  @override
  State<ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<ResolveSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _creating = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bibCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _bibCtrl.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.clearSearch();
    });
    super.dispose();
  }

  void _submitNew() {
    final name = _nameCtrl.text.trim();
    final bib = int.tryParse(_bibCtrl.text);
    if (name.isEmpty || bib == null) return;
    widget.controller.resolveAsNewRunner(widget.entry.id, name: name, newBib: bib);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Fix ${ordinal(widget.entry.position)} place';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            _SheetHeader(title: title),
            const Divider(height: 1, color: AppColors.borderColor),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) => ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: _creating
                      ? _buildCreateForm(context)
                      : _buildSearchFlow(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search flow ─────────────────────────────────────────────────────────────

  List<Widget> _buildSearchFlow(BuildContext context) {
    return [
      _EntryDetailCard(entry: widget.entry),
      const SizedBox(height: AppSpacing.lg),
      _SearchSection(
        controller: widget.controller,
        entry: widget.entry,
        searchCtrl: _searchCtrl,
        onResolved: () => Navigator.pop(context),
      ),
      const Divider(height: AppSpacing.xxl, color: AppColors.borderColor),
      _CreateRunnerButton(onTap: () => setState(() => _creating = true)),
      const SizedBox(height: AppSpacing.sm),
      _LeaveForCoachButton(onTap: () => Navigator.pop(context)),
    ];
  }

  // ── Create runner form ───────────────────────────────────────────────────────

  List<Widget> _buildCreateForm(BuildContext context) {
    final canSubmit =
        _nameCtrl.text.trim().isNotEmpty && _bibCtrl.text.trim().isNotEmpty;
    return [
      GestureDetector(
        onTap: () {
          widget.controller.clearSearch();
          setState(() => _creating = false);
        },
        child: Text(
          '← Back',
          style: AppTypography.smallBodySemibold.copyWith(
            color: AppColors.primaryColor,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      _FormField(
        label: 'Name',
        hint: "Runner's full name",
        controller: _nameCtrl,
        onChanged: (_) => setState(() {}),
      ),
      _FormField(
        label: 'Bib #',
        hint: 'e.g. ${widget.entry.bib}',
        controller: _bibCtrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.sm),
      _AddRunnerButton(enabled: canSubmit, onTap: _submitNew),
    ];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor,
              borderRadius: BorderRadius.circular(AppBorderRadius.full),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: AppTypography.titleSemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryDetailCard extends StatelessWidget {
  const _EntryDetailCard({required this.entry});

  final FixerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${entry.bib}',
            style: AppTypography.titleSemibold.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.darkColor,
            ),
          ),
          Text(
            entry.contextMessage,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.controller,
    required this.entry,
    required this.searchCtrl,
    required this.onResolved,
  });

  final FixerController controller;
  final FixerEntry entry;
  final TextEditingController searchCtrl;
  final VoidCallback onResolved;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEARCH BY NAME',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.mediumColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: searchCtrl,
          onChanged: controller.search,
          style: AppTypography.smallBodyRegular.copyWith(
            color: AppColors.darkColor,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Singh, Priya, Tom G…',
            hintStyle: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.mediumColor,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
              borderSide:
                  const BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
          ),
        ),
        if (controller.searchResults.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _CandidateList(
            results: controller.searchResults,
            entryBib: entry.bib,
            onPick: (runner) {
              controller.resolveWithRunner(entry.id, runner);
              onResolved();
            },
          ),
        ],
        if (searchCtrl.text.isNotEmpty && controller.searchResults.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              'No matches',
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({
    required this.results,
    required this.entryBib,
    required this.onPick,
  });

  final List<Runner> results;
  final int entryBib;
  final ValueChanged<Runner> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: results.map((runner) {
        return _CandidateRow(
          runner: runner,
          entryBib: entryBib,
          onTap: () => onPick(runner),
        );
      }).toList(),
    );
  }
}

class _CandidateRow extends StatefulWidget {
  const _CandidateRow({
    required this.runner,
    required this.entryBib,
    required this.onTap,
  });

  final Runner runner;
  final int entryBib;
  final VoidCallback onTap;

  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: AppColors.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Bib badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(AppBorderRadius.sm),
              ),
              child: Center(
                child: Text(
                  '#${widget.runner.bibNumber}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mediumColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Name + team
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.runner.name ?? widget.runner.bibNumber,
                    style: AppTypography.smallBodySemibold.copyWith(
                      color: AppColors.darkColor,
                    ),
                  ),
                  if (widget.runner.teamAbbreviation != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (widget.runner.teamColor != null)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: widget.runner.teamColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          widget.runner.teamAbbreviation!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.mediumColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRunnerButton extends StatefulWidget {
  const _CreateRunnerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CreateRunnerButton> createState() => _CreateRunnerButtonState();
}

class _CreateRunnerButtonState extends State<_CreateRunnerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Use amber for "create new runner" matching prototype
    const amber = Color(0xFFF59E0B);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? amber.withValues(alpha: AppOpacity.medium)
              : amber.withValues(alpha: AppOpacity.light - 0.02),
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(
            color: amber.withValues(alpha: AppOpacity.strong + 0.1),
          ),
        ),
        child: Center(
          child: Text(
            'Create new runner',
            style: AppTypography.smallBodySemibold.copyWith(
              color: amber,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveForCoachButton extends StatefulWidget {
  const _LeaveForCoachButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_LeaveForCoachButton> createState() => _LeaveForCoachButtonState();
}

class _LeaveForCoachButtonState extends State<_LeaveForCoachButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.surfaceColor : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Center(
          child: Text(
            'Leave for coach',
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
        ),
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
    this.keyboardType = TextInputType.text,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: AppColors.darkColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: AppTypography.smallBodyRegular.copyWith(
              color: AppColors.darkColor,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.lightColor,
              ),
              filled: true,
              fillColor: AppColors.backgroundColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
                borderSide: const BorderSide(
                  color: AppColors.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRunnerButton extends StatelessWidget {
  const _AddRunnerButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg - 2),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primaryColor, Color(0xFFF07A50)],
                )
              : null,
          color: enabled ? null : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: AppOpacity.medium),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            'Add Runner',
            style: AppTypography.smallBodySemibold.copyWith(
              color: enabled ? Colors.white : AppColors.mediumColor,
            ),
          ),
        ),
      ),
    );
  }
}
