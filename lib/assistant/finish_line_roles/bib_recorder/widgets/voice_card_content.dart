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
/// a unified editable text field when a bib is pending or manual mode
/// is active, or an idle prompt otherwise.
class VoiceCardContent extends StatelessWidget {
  const VoiceCardContent({
    super.key,
    required this.isListening,
    required this.isProcessing,
    required this.bars,
    required this.isManualMode,
    required this.hasPendingBib,
    required this.bibController,
    required this.focusNode,
    required this.onFieldChanged,
    required this.onFieldSubmitted,
    this.flagFor,
    this.runnerFor,
  });

  final bool isListening;
  final bool isProcessing;
  final List<double> bars;
  final bool isManualMode;
  final bool hasPendingBib;
  final TextEditingController bibController;
  final FocusNode focusNode;
  final ValueChanged<String> onFieldChanged;
  final ValueChanged<String> onFieldSubmitted;
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

    if (hasPendingBib || isManualMode) {
      final parsedBib = int.tryParse(bibController.text.trim());
      final bibFlag = parsedBib != null ? flagFor?.call(parsedBib) : null;
      final runner = parsedBib != null ? runnerFor?.call(parsedBib) : null;

      return Column(
        children: [
          TextField(
            controller: bibController,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            autofocus: isManualMode,
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
            onChanged: onFieldChanged,
            onSubmitted: onFieldSubmitted,
          ),
          if (parsedBib != null) _buildRunnerInfo(parsedBib, runner, bibFlag),
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

  /// Shared runner-info row and flag warning — used by both voice and manual
  /// pending states.
  Widget _buildRunnerInfo(int bib, Runner? runner, String? flag) {
    return Column(
      children: [
        if (runner != null && flag == null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: runner.teamColor ?? AppColors.mediumColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${runner.name ?? ''}, ${runner.teamAbbreviation ?? ''}',
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
              '\u26A0 Already recorded \u2014 will be flagged',
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
              'Not in roster \u2014 will be flagged',
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.statusSetup,
              ),
            ),
          ),
      ],
    );
  }
}

/// Re-record / Add-bib row shown after a bib is parsed (both modes).
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
