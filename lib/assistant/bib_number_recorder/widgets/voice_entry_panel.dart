import 'package:flutter/material.dart';

import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../shared/widgets/race_day_controls.dart';
import '../controller/voice_entry_controller.dart';

/// Chooses how bibs go in: typed on the keypad, or said aloud.
class EntryModeToggle extends StatelessWidget {
  const EntryModeToggle({super.key, required this.voice});

  final VoiceEntryController voice;

  @override
  Widget build(BuildContext context) {
    final busy = voice.state == VoiceEntryState.listening ||
        voice.state == VoiceEntryState.processing;
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
            value: false,
            icon: Icon(Icons.dialpad, size: 18),
            label: Text('Keypad')),
        ButtonSegment(
            value: true,
            icon: Icon(Icons.mic_none, size: 18),
            label: Text('Voice')),
      ],
      selected: {voice.enabled},
      showSelectedIcon: false,
      onSelectionChanged:
          busy ? null : (choice) => voice.setEnabled(choice.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor:
            AppColors.primaryColor.withValues(alpha: 0.12),
        selectedForegroundColor: AppColors.primaryColor,
        visualDensity: VisualDensity.compact,
        textStyle: AppTypography.smallBodySemibold,
      ),
    );
  }
}

/// The bottom of the Bib Recorder in voice mode: what was just heard, and a
/// big button to hold while saying the next bib.
class VoiceEntryPanel extends StatelessWidget {
  const VoiceEntryPanel({
    super.key,
    required this.voice,
    required this.describe,
    required this.onUndo,
  });

  final VoiceEntryController voice;

  /// The runner a bib belongs to, such as "Alice, EAG", or null if none.
  final String? Function(String bib) describe;

  /// Takes back the last bib heard.
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    switch (voice.state) {
      case VoiceEntryState.off:
        return const SizedBox.shrink();
      case VoiceEntryState.preparing:
        return const _Notice(
          icon: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          text: 'Getting voice ready. The first time, this downloads about '
              '28 MB, so do it before race day.',
        );
      case VoiceEntryState.failed:
        return _Notice(
          icon: const Icon(Icons.mic_off, color: AppColors.redColor),
          text: '${voice.error?.userMessage ?? 'Voice is not working.'} '
              'Use the keypad, or try again.',
          action: TextButton(
            onPressed: voice.retry,
            child: const Text('Try Again'),
          ),
        );
      case VoiceEntryState.ready:
      case VoiceEntryState.listening:
      case VoiceEntryState.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeardLine(voice: voice, describe: describe, onUndo: onUndo),
            const SizedBox(height: AppSpacing.sm),
            _HoldToTalk(voice: voice),
          ],
        );
    }
  }
}

class _HoldToTalk extends StatelessWidget {
  const _HoldToTalk({required this.voice});

  final VoiceEntryController voice;

  @override
  Widget build(BuildContext context) {
    final listening = voice.state == VoiceEntryState.listening;
    final processing = voice.state == VoiceEntryState.processing;
    return BigActionButton(
      key: const ValueKey('hold_to_talk_button'),
      label: listening
          ? 'Listening…'
          : processing
              ? 'Checking…'
              : 'Hold and Say Bib',
      sublabel: listening ? 'Let go when you have said it' : null,
      icon: Icons.mic,
      color: listening ? AppColors.darkPrimaryColor : AppColors.primaryColor,
      onTapDown: voice.startListening,
      onRelease: voice.stopListening,
    );
  }
}

class _HeardLine extends StatelessWidget {
  const _HeardLine({
    required this.voice,
    required this.describe,
    required this.onUndo,
  });

  final VoiceEntryController voice;
  final String? Function(String bib) describe;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final heard = voice.lastHeard;
    // The bib just heard, large, so the volunteer can check it at a glance
    // between runners. It fades in afresh for each bib, even a repeat.
    final Widget child;
    if (!voice.missed && heard != null) {
      child = _HeardCard(
        key: ValueKey(voice.heardCount),
        bib: heard,
        who: describe(heard),
        onUndo: onUndo,
      );
    } else {
      child = _HintLine(
        key: ValueKey(voice.missed),
        missed: voice.missed,
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: child,
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({super.key, required this.missed});

  final bool missed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Text(
        missed
            ? 'Didn\'t catch that. Hold the button and say it again.'
            : 'Say each runner\'s bib as they finish, like "four one two".',
        style: AppTypography.bodySemibold.copyWith(
            color: missed ? AppColors.redColor : AppColors.mediumColor),
      ),
    );
  }
}

class _HeardCard extends StatelessWidget {
  const _HeardCard({
    super.key,
    required this.bib,
    required this.who,
    required this.onUndo,
  });

  final String bib;

  /// The runner with this bib ("Alice, EAG"), or null if none has it.
  final String? who;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final known = who != null;
    final accent = known ? AppColors.statusFinished : AppColors.redColor;
    return Semantics(
      container: true,
      label: known ? 'Heard $bib, $who' : 'Heard $bib, not on the roster',
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Row(
          children: [
            // The number, as big as fits beside the name.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  bib,
                  maxLines: 1,
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.darkColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                who ?? 'Not on the roster',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySemibold.copyWith(
                    color: known ? AppColors.darkColor : AppColors.redColor),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: onUndo,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 44),
                foregroundColor: AppColors.darkColor,
                side: const BorderSide(color: AppColors.borderColor),
              ),
              child: const Text('Undo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final Widget icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text,
                style: AppTypography.bodyRegular
                    .copyWith(color: AppColors.darkColor)),
          ),
          ?action,
        ],
      ),
    );
  }
}
