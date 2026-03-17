import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_controls.dart';
import 'package:xceleration/assistant/shared/models/runner.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Content displayed inside the voice-input card.
///
/// Shows waveform bars while listening, a spinner while processing,
/// the recognised bib + runner info, or a manual text field.
class VoiceCardContent extends StatelessWidget {
  const VoiceCardContent({
    super.key,
    required this.isListening,
    required this.isProcessing,
    required this.bars,
    required this.isManualMode,
    this.displayBib,
    this.flag,
    this.runner,
    this.parsedManualBib,
    this.manualBibController,
    this.onAddBib,
    this.flagFor,
    this.runnerFor,
  });

  final bool isListening;
  final bool isProcessing;
  final List<double> bars;
  final bool isManualMode;
  final int? displayBib;
  final String? flag;
  final Runner? runner;
  final int? parsedManualBib;
  final TextEditingController? manualBibController;
  final void Function(int)? onAddBib;
  final String? Function(int)? flagFor;
  final Runner? Function(int)? runnerFor;

  @override
  Widget build(BuildContext context) {
    if (isListening) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: bars
            .map(
              (h) => AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor
                      .withValues(alpha: 0.6 + (h / 32) * 0.4),
                  borderRadius: BorderRadius.circular(AppBorderRadius.full),
                ),
              ),
            )
            .toList(),
      );
    }

    if (isProcessing) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryColor,
          ),
        ),
      );
    }

    if (displayBib != null) {
      return Column(
        children: [
          Text(
            '#$displayBib',
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.darkColor,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          if (runner != null && flag == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: runner!.teamColor ?? AppColors.mediumColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${runner!.name ?? ''}, ${runner!.teamAbbreviation ?? ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumColor,
                  ),
                ),
              ],
            ),
          ],
          if (flag == 'duplicate')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                '⚠ Already recorded — will be flagged',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.redColor,
                ),
              ),
            ),
          if (flag == 'unknown')
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Not in roster — will be flagged',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.statusSetup,
                ),
              ),
            ),
        ],
      );
    }

    if (isManualMode) {
      final manualFlag =
          parsedManualBib != null ? flagFor?.call(parsedManualBib!) : null;
      final manualRunner =
          parsedManualBib != null ? runnerFor?.call(parsedManualBib!) : null;

      return Column(
        children: [
          TextField(
            controller: manualBibController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            autofocus: true,
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.darkColor,
              letterSpacing: -2,
              height: 1,
            ),
            decoration: InputDecoration(
              hintText: '#',
              hintStyle: AppTypography.displaySmall.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.lightColor,
                letterSpacing: -2,
                height: 1,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onSubmitted: (value) {
              final bib = int.tryParse(value.trim());
              if (bib == null) return;
              onAddBib?.call(bib);
              manualBibController?.clear();
            },
          ),
          if (parsedManualBib != null) ...[
            const SizedBox(height: AppSpacing.sm),
            if (manualRunner != null && manualFlag == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: manualRunner.teamColor ?? AppColors.mediumColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${manualRunner.name ?? ''}, ${manualRunner.teamAbbreviation ?? ''}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                ],
              ),
            if (manualFlag == 'duplicate')
              Text(
                '⚠ Already recorded — will be flagged',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.redColor,
                ),
              ),
            if (manualFlag == 'unknown')
              Text(
                'Not in roster — will be flagged',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.statusSetup,
                ),
              ),
          ],
        ],
      );
    }

    return Center(
      child: Text(
        'Hold mic to record a bib number',
        style: AppTypography.smallBodyRegular.copyWith(
          color: AppColors.mediumColor,
        ),
      ),
    );
  }
}

/// Re-record / Add-bib row shown in manual input mode after a bib is parsed.
class ManualConfirmRow extends StatelessWidget {
  const ManualConfirmRow({
    super.key,
    required this.bib,
    this.flag,
    required this.onReRecord,
    required this.onConfirm,
  });

  final int bib;
  final String? flag;
  final VoidCallback onReRecord;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final confirmColor = flag == 'duplicate'
        ? AppColors.redColor
        : flag == 'unknown'
            ? AppColors.statusSetup
            : AppColors.primaryColor;

    return Row(
      children: [
        Expanded(
          child: RaceActionButton(
            label: 'Re-record',
            color: AppColors.mediumColor,
            backgroundColor: Colors.white,
            borderColor: AppColors.borderColor,
            onTap: onReRecord,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: RaceActionButton(
            label: flag != null ? 'Add Anyway' : 'Add #$bib',
            color: Colors.white,
            backgroundColor: confirmColor,
            onTap: onConfirm,
          ),
        ),
      ],
    );
  }
}
