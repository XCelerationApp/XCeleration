import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_controls.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_shadows.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Voice-mode input row: centred mic button with a fade-in Re-record button.
class RaceMicArea extends StatelessWidget {
  const RaceMicArea({
    super.key,
    required this.isListening,
    required this.hasEntries,
    required this.onMicDown,
    required this.onMicUp,
    required this.onReRecord,
  });

  final bool isListening;
  final bool hasEntries;
  final Future<void> Function() onMicDown;
  final Future<void> Function() onMicUp;
  final VoidCallback onReRecord;

  @override
  Widget build(BuildContext context) {
    const sideWidth = 96.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: sideWidth,
          child: AnimatedOpacity(
            opacity: hasEntries ? 1.0 : 0.0,
            duration: AppAnimations.standard,
            child: IgnorePointer(
              ignoring: !hasEntries,
              child: RaceActionButton(
                label: 'Re-record',
                color: AppColors.mediumColor,
                backgroundColor: Colors.white,
                borderColor: AppColors.borderColor,
                onTap: onReRecord,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _MicButton(
          isListening: isListening,
          onMicDown: onMicDown,
          onMicUp: onMicUp,
        ),
        const SizedBox(width: AppSpacing.md),
        const SizedBox(width: sideWidth),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.isListening,
    required this.onMicDown,
    required this.onMicUp,
  });

  final bool isListening;
  final Future<void> Function() onMicDown;
  final Future<void> Function() onMicUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onPanStart: (_) => onMicDown(),
          onPanEnd: (_) => onMicUp(),
          onTapDown: (_) => onMicDown(),
          onTapUp: (_) => onMicUp(),
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? AppColors.primaryColor
                  : AppColors.surfaceColor,
              border: Border.all(
                color: isListening
                    ? AppColors.primaryColor
                    : AppColors.borderColor,
                width: 2.5,
              ),
              boxShadow: isListening ? AppShadows.glow : [],
            ),
            child: Icon(
              Icons.mic,
              color: isListening ? Colors.white : AppColors.mediumColor,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isListening ? 'LISTENING…' : 'HOLD TO RECORD',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.mediumColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
