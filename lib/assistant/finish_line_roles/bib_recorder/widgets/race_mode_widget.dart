import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_bottom_bar.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mic_area.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_mode_controls.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/race_header.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/swipe_bib_row_widget.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/voice_card_content.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Active recording screen. Shows the voice input area and live bib list.
class RaceModeWidget extends StatefulWidget {
  const RaceModeWidget({super.key, required this.controller});

  final BibRecorderV2Controller controller;

  @override
  State<RaceModeWidget> createState() => _RaceModeWidgetState();
}

class _RaceModeWidgetState extends State<RaceModeWidget> {
  // Wave animation — purely visual, lives in widget state.
  double _wavePhase = 0;
  Timer? _waveTimer;

  // Input mode state — purely visual, lives in widget state.
  bool _isManualMode = false;
  final TextEditingController _manualBibController = TextEditingController();

  BibRecorderV2Controller get _ctrl => widget.controller;

  @override
  void dispose() {
    _waveTimer?.cancel();
    _manualBibController.dispose();
    super.dispose();
  }

  void _startWave() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => setState(() => _wavePhase += 1),
    );
  }

  void _stopWave() {
    _waveTimer?.cancel();
    _waveTimer = null;
  }

  Future<void> _onMicDown() async {
    _startWave();
    await _ctrl.startListening();
  }

  Future<void> _onMicUp() async {
    _stopWave();
    await _ctrl.stopListening();
  }

  List<double> get _bars {
    return List.generate(20, (i) {
      final v = sin((_wavePhase + i) * 0.6) * 0.5 +
          0.5 +
          sin(_wavePhase * 1.7 + i * 1.3) * 0.3;
      return max(3.0, (v * 28).roundToDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return ColoredBox(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                RaceHeader(
                  raceName: _ctrl.selectedRace?.formattedName ?? '',
                  entryCount: _ctrl.entries.length,
                  raceStarted: _raceStarted,
                ),
                _buildVoiceArea(),
                Expanded(child: _buildList()),
                RaceBottomBar(
                  isRaceStarted: _raceStarted,
                  entryCount: _ctrl.entries.length,
                  runners: _ctrl.runners,
                  onBeginRace: _ctrl.beginRace,
                  onStopRace: _ctrl.stopRace,
                  onDeleteRace: _ctrl.deleteRace,
                  onClearEntries: _ctrl.clearEntries,
                  onLeaveRace: _ctrl.leaveRace,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _raceStarted => _ctrl.raceStarted;

  Widget _buildVoiceArea() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _manualBibController,
      builder: (context, textValue, _) {
        final parsedBib = int.tryParse(textValue.text.trim());
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            children: [
              if (_raceStarted) ...[
                RaceInputModeToggle(
                  isManualMode: _isManualMode,
                  onSwitchToVoice: () => setState(() {
                    _isManualMode = false;
                    _manualBibController.clear();
                  }),
                  onSwitchToManual: () =>
                      setState(() => _isManualMode = true),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildVoiceCard(parsedBib),
              if (_isManualMode && parsedBib != null) ...[
                const SizedBox(height: AppSpacing.md),
                ManualConfirmRow(
                  bib: parsedBib,
                  flag: _ctrl.flagFor(parsedBib),
                  onReRecord: _manualBibController.clear,
                  onConfirm: () {
                    _ctrl.addBib(parsedBib);
                    _manualBibController.clear();
                  },
                ),
              ] else if (_raceStarted && !_isManualMode) ...[
                const SizedBox(height: AppSpacing.md),
                RaceMicArea(
                  isListening: _ctrl.isListening,
                  hasEntries: _ctrl.entries.isNotEmpty,
                  onMicDown: _onMicDown,
                  onMicUp: _onMicUp,
                  onReRecord: _ctrl.reRecordLast,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _cardBorderColor(int? parsedManualBib) {
    if (_isManualMode) {
      if (parsedManualBib == null) return AppColors.borderColor;
      final flag = _ctrl.flagFor(parsedManualBib);
      if (flag == 'duplicate') {
        return AppColors.redColor.withValues(alpha: AppOpacity.solid);
      }
      if (flag == 'unknown') {
        return AppColors.statusSetup.withValues(alpha: AppOpacity.solid);
      }
      return AppColors.primaryColor.withValues(alpha: AppOpacity.solid);
    }
    // Voice mode — colour based on the last displayed bib (respects _awaitingRecord).
    final displayBib = _ctrl.lastAddedBib;
    if (displayBib != null && _ctrl.entries.isNotEmpty) {
      final lastEntry = _ctrl.entries.first;
      final flag = _ctrl.flagFor(lastEntry.bib, excludeId: lastEntry.id);
      if (flag == 'duplicate') {
        return AppColors.redColor.withValues(alpha: AppOpacity.solid);
      }
      if (flag == 'unknown') {
        return AppColors.statusSetup.withValues(alpha: AppOpacity.solid);
      }
      return AppColors.primaryColor.withValues(alpha: AppOpacity.solid);
    }
    if (_ctrl.isListening) {
      return AppColors.primaryColor.withValues(alpha: AppOpacity.solid);
    }
    return AppColors.borderColor;
  }

  Widget _buildVoiceCard(int? parsedManualBib) {
    // Use lastAddedBib so the card goes blank when _awaitingRecord is true
    // (after Re-record is pressed) — the entry stays in the list below.
    final displayBib = !_isManualMode ? _ctrl.lastAddedBib : null;
    final lastEntry = (displayBib != null && _ctrl.entries.isNotEmpty)
        ? _ctrl.entries.first
        : null;
    final flag = lastEntry != null
        ? _ctrl.flagFor(lastEntry.bib, excludeId: lastEntry.id)
        : null;
    final runner = displayBib != null ? _ctrl.runnerFor(displayBib) : null;

    return AnimatedContainer(
      duration: AppAnimations.standard,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: _cardBorderColor(parsedManualBib), width: 1.5),
      ),
      child: VoiceCardContent(
        isListening: _ctrl.isListening,
        isProcessing: _ctrl.isProcessing,
        bars: _bars,
        isManualMode: _isManualMode,
        displayBib: displayBib,
        flag: flag,
        runner: runner,
        parsedManualBib: parsedManualBib,
        manualBibController: _manualBibController,
        onAddBib: _ctrl.addBib,
        flagFor: (bib) => _ctrl.flagFor(bib),
        runnerFor: _ctrl.runnerFor,
      ),
    );
  }

  Widget _buildList() {
    // Skip entries[0] from the list only when the card is actively displaying
    // it (voice mode, not listening/processing, and a bib is shown in card).
    // While listening or processing, the bib moves into the list so the card
    // can show the waveform / spinner without hiding the previous entry.
    final skipFirst = !_isManualMode &&
        !_ctrl.isListening &&
        !_ctrl.isProcessing &&
        _ctrl.lastAddedBib != null;
    final offset = skipFirst ? 1 : 0;
    final listCount = _ctrl.entries.length - offset;

    if (listCount <= 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏁', style: TextStyle(fontSize: 32)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Enter the first bib above',
              style: AppTypography.smallBodyRegular.copyWith(
                color: AppColors.mediumColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: listCount,
      itemBuilder: (_, i) {
        final entry = _ctrl.entries[i + offset];
        return SwipeBibRowWidget(
          key: ValueKey(entry.id),
          entry: entry,
          position: _ctrl.entries.length - offset - i,
          controller: _ctrl,
          isNew: false,
        );
      },
    );
  }
}
