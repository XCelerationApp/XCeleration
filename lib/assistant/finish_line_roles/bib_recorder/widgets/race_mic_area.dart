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
    required this.voiceReady,
    required this.onMicDown,
    required this.onMicUp,
    required this.onReRecord,
  });

  final bool isListening;
  final bool hasEntries;
  final bool voiceReady;
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
          voiceReady: voiceReady,
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
    required this.voiceReady,
    required this.onMicDown,
    required this.onMicUp,
  });

  final bool isListening;
  final bool voiceReady;
  final Future<void> Function() onMicDown;
  final Future<void> Function() onMicUp;

  String get _label {
    if (!voiceReady) return 'LOADING MODEL…';
    if (isListening) return 'LISTENING…';
    return 'HOLD TO RECORD';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onPanStart: voiceReady ? (_) => onMicDown() : null,
          onPanEnd: voiceReady ? (_) => onMicUp() : null,
          onTapDown: voiceReady ? (_) => onMicDown() : null,
          onTapUp: voiceReady ? (_) => onMicUp() : null,
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            width: 92,
            height: 92,
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
            child: voiceReady
                ? Icon(
                    Icons.mic,
                    color:
                        isListening ? Colors.white : AppColors.mediumColor,
                    size: 35,
                  )
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.mediumColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _label,
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
