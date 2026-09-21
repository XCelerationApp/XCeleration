import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/controller/fixer_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/candidate_list.dart';
import 'package:xceleration/assistant/finish_line_roles/fixer/widgets/resolve_sheet_controls.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/fixer_entry.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/ordinal.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
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
    widget.controller.clearSearch();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _bibCtrl.dispose();
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
      SearchSection(
        controller: widget.controller,
        entry: widget.entry,
        searchCtrl: _searchCtrl,
        onResolved: () => Navigator.pop(context),
      ),
      const Divider(height: AppSpacing.xxl, color: AppColors.borderColor),
      CreateRunnerButton(onTap: () => setState(() => _creating = true)),
      const SizedBox(height: AppSpacing.sm),
      LeaveForCoachButton(onTap: () => Navigator.pop(context)),
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
      ResolveFormField(
        label: 'Name',
        hint: "Runner's full name",
        controller: _nameCtrl,
        onChanged: (_) => setState(() {}),
      ),
      ResolveFormField(
        label: 'Bib #',
        hint: 'e.g. ${widget.entry.bib}',
        controller: _bibCtrl,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.sm),
      AddRunnerButton(enabled: canSubmit, onTap: _submitNew),
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
            style: AppTypography.bibStandard.copyWith(
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
