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
    final String text;
    Color color = AppColors.mediumColor;
    Widget? action;
    final heard = voice.lastHeard;
    if (voice.missed) {
      text = 'Didn\'t catch that. Hold the button and say it again.';
      color = AppColors.redColor;
    } else if (heard != null) {
      final who = describe(heard);
      text = who == null ? 'Heard $heard (not on the roster)' : 'Heard $heard · $who';
      if (who == null) color = AppColors.redColor;
      action = TextButton(onPressed: onUndo, child: const Text('Undo'));
    } else {
      text = 'Say each runner\'s bib as they finish, like "four one two".';
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.only(left: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: AppTypography.bodySemibold.copyWith(color: color)),
          ),
          ?action,
        ],
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
