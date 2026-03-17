import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/models/verifier_entry.dart';
import 'package:xceleration/assistant/finish_line_roles/verifier/controller/verifier_controller.dart';
import 'package:xceleration/coach/bib_conflict_resolution/utils/ordinal.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Card displayed in the Verifier queue for a single bib entry.
///
/// Layout (matches prototype):
///   • Optional full-width flag banner (DUPLICATE / UNKNOWN) at the top
///   • Position ordinal + large bib number on the same row
///   • Runner name (large) or "NOT IN ROSTER" for unknowns
///   • Team colour dot + team abbreviation
///   • Action buttons:
///       - UNKNOWN  → single "Got it"
///       - Normal   → Wrong | Skip | Correct (flex:2)
///       - Acted    → status label + Undo button (3-second window)
class VerifierEntryCard extends StatelessWidget {
  const VerifierEntryCard({
    super.key,
    required this.entry,
    required this.controller,
  });

  final VerifierEntry entry;
  final VerifierController controller;

  bool get _isPending => entry.status == VerificationStatus.pending;

  Color get _actColor => switch (entry.status) {
        VerificationStatus.verified => AppColors.statusFinished,
        VerificationStatus.flagged => AppColors.redColor,
        VerificationStatus.skipped => AppColors.mediumColor,
        VerificationStatus.pending => AppColors.mediumColor,
      };

  @override
  Widget build(BuildContext context) {
    final borderColor = _isPending
        ? switch (entry.flag) {
            BibFlag.duplicate =>
              AppColors.redColor.withValues(alpha: AppOpacity.strong),
            BibFlag.unknown =>
              AppColors.statusSetup.withValues(alpha: AppOpacity.strong),
            BibFlag.none => AppColors.borderColor,
          }
        : _actColor.withValues(alpha: AppOpacity.solid);

    final bgColor = _isPending
        ? Colors.white
        : _actColor.withValues(alpha: AppOpacity.faint);

    return AnimatedContainer(
      duration: AppAnimations.standard,
      margin: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.xl),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: _isPending
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppOpacity.faint),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Opacity(
        opacity: _isPending ? 1.0 : 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.flag != BibFlag.none && _isPending)
              _FlagBanner(flag: entry.flag),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PositionBibRow(position: entry.position, bib: entry.bib),
                  const SizedBox(height: AppSpacing.sm),
                  _RunnerName(entry: entry),
                  if (entry.runnerName != null && entry.teamAbbreviation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _TeamRow(
                      teamColor: entry.teamColor,
                      teamAbbreviation: entry.teamAbbreviation!,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _isPending
                      ? _ActionButtons(entry: entry, controller: controller)
                      : _ActedRow(
                          status: entry.status,
                          actColor: _actColor,
                          onUndo: () => controller.undo(entry.id),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FlagBanner extends StatelessWidget {
  const _FlagBanner({required this.flag});

  final BibFlag flag;

  @override
  Widget build(BuildContext context) {
    final isDuplicate = flag == BibFlag.duplicate;
    final color = isDuplicate ? AppColors.redColor : AppColors.statusSetup;
    final label = isDuplicate
        ? '⚠ DUPLICATE BIB — verify carefully'
        : 'UNKNOWN BIB';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDuplicate ? AppOpacity.light : AppOpacity.dim),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppBorderRadius.xl - 2),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PositionBibRow extends StatelessWidget {
  const _PositionBibRow({required this.position, required this.bib});

  final int position;
  final int bib;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          ordinal(position),
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.mediumColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '#$bib',
          style: AppTypography.displaySmall.copyWith(
            fontWeight: FontWeight.w900,
            color: AppColors.darkColor,
          ),
        ),
      ],
    );
  }
}

class _RunnerName extends StatelessWidget {
  const _RunnerName({required this.entry});

  final VerifierEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.flag == BibFlag.unknown && entry.runnerName == null) {
      return Text(
        'NOT IN ROSTER',
        style: AppTypography.titleSemibold.copyWith(
          color: AppColors.statusSetup,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      );
    }
    return Text(
      entry.runnerName ?? '',
      style: AppTypography.titleSemibold.copyWith(
        color: AppColors.darkColor,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.15,
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.teamColor, required this.teamAbbreviation});

  final Color? teamColor;
  final String teamAbbreviation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: teamColor ?? AppColors.mediumColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          teamAbbreviation,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.mediumColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.entry, required this.controller});

  final VerifierEntry entry;
  final VerifierController controller;

  @override
  Widget build(BuildContext context) {
    if (entry.flag == BibFlag.unknown) {
      return _ActionBtn(
        label: 'Got it — sending to Fixer',
        bg: AppColors.surfaceColor,
        color: AppColors.mediumColor,
        onTap: () => controller.flag(entry.id),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            label: 'Wrong',
            bg: AppColors.redColor.withValues(alpha: 0.08),
            color: AppColors.redColor,
            onTap: () => controller.flag(entry.id),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _ActionBtn(
            label: 'Skip',
            bg: AppColors.surfaceColor,
            color: AppColors.mediumColor,
            onTap: () => controller.skip(entry.id),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: _ActionBtn(
            label: 'Correct',
            bg: AppColors.statusFinished.withValues(alpha: AppOpacity.light),
            color: AppColors.statusFinished,
            onTap: () => controller.verify(entry.id),
          ),
        ),
      ],
    );
  }
}

class _ActedRow extends StatelessWidget {
  const _ActedRow({
    required this.status,
    required this.actColor,
    required this.onUndo,
  });

  final VerificationStatus status;
  final Color actColor;
  final VoidCallback onUndo;

  String get _label => switch (status) {
        VerificationStatus.verified => 'Correct',
        VerificationStatus.flagged => 'Sent to Fixer',
        VerificationStatus.skipped => 'Skipped',
        VerificationStatus.pending => '',
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            _label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: actColor,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _UndoButton(color: actColor, onTap: onUndo),
      ],
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.label,
    required this.bg,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: AppOpacity.medium)
              : widget.bg,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: widget.color.withValues(alpha: AppOpacity.medium),
          ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoButton extends StatefulWidget {
  const _UndoButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withValues(alpha: AppOpacity.faint)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
          border: Border.all(
            color: widget.color.withValues(alpha: AppOpacity.solid),
          ),
        ),
        child: Text(
          'Undo',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
