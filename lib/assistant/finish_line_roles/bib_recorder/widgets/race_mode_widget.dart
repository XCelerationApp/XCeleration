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

  // Unified card state — shared by voice and manual modes.
  final TextEditingController _cardBibController = TextEditingController();
  final FocusNode _cardBibFocusNode = FocusNode();
  Timer? _autoSubmitTimer;
  bool _hasPendingBib = false;

  static const _autoSubmitDelay = Duration(seconds: 4);

  BibRecorderV2Controller get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl.onBibPending = _onBibPending;
    _cardBibFocusNode.addListener(_onCardFieldFocusChange);
  }

  @override
  void didUpdateWidget(RaceModeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.onBibPending = null;
      _ctrl.onBibPending = _onBibPending;
    }
  }

  @override
  void dispose() {
    _ctrl.onBibPending = null;
    _waveTimer?.cancel();
    _autoSubmitTimer?.cancel();
    _cardBibController.dispose();
    _cardBibFocusNode.removeListener(_onCardFieldFocusChange);
    _cardBibFocusNode.dispose();
    super.dispose();
  }

  // ── Auto-submit timer ────────────────────────────────────────────────────

  /// Called by the controller when voice recognition produces a bib.
  void _onBibPending(int bib) {
    _autoSubmitTimer?.cancel();
    _cardBibController.text = bib.toString();
    _cardBibController.selection = TextSelection.collapsed(
      offset: _cardBibController.text.length,
    );
    setState(() => _hasPendingBib = true);
    _startAutoSubmitTimer();
  }

  void _startAutoSubmitTimer() {
    final parsedBib = int.tryParse(_cardBibController.text.trim());
    if (parsedBib == null) return;
    _autoSubmitTimer?.cancel();
    _autoSubmitTimer = Timer(_autoSubmitDelay, _autoSubmit);
  }

  void _autoSubmit() {
    final bib = int.tryParse(_cardBibController.text.trim());
    if (bib == null) return;
    _ctrl.addBib(bib);
    _resetCard();
  }

  void _resetCard() {
    _autoSubmitTimer?.cancel();
    _cardBibController.clear();
    setState(() => _hasPendingBib = false);
  }

  void _onCardFieldFocusChange() {
    if (_cardBibFocusNode.hasFocus) {
      _autoSubmitTimer?.cancel();
    } else if (_hasPendingBib || _isManualMode) {
      final parsedBib = int.tryParse(_cardBibController.text.trim());
      if (parsedBib != null) _startAutoSubmitTimer();
    }
  }

  void _onFieldChanged(String value) {
    // Restart timer on every keystroke if text is valid.
    _autoSubmitTimer?.cancel();
    final bib = int.tryParse(value.trim());
    if (bib != null && !_cardBibFocusNode.hasFocus) {
      _startAutoSubmitTimer();
    }
    setState(() {});
  }

  void _onFieldSubmitted(String value) {
    final bib = int.tryParse(value.trim());
    if (bib == null) return;
    _ctrl.addBib(bib);
    _resetCard();
  }

  // ── Wave animation ───────────────────────────────────────────────────────

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
    // If there's a pending bib, auto-submit it before starting a new recording.
    if (_hasPendingBib) {
      final bib = int.tryParse(_cardBibController.text.trim());
      if (bib != null) _ctrl.addBib(bib);
      _resetCard();
    }
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

  // ── Build ────────────────────────────────────────────────────────────────

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
    final parsedBib = int.tryParse(_cardBibController.text.trim());
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
              onSwitchToVoice: () {
                _resetCard();
                setState(() => _isManualMode = false);
              },
              onSwitchToManual: () {
                _resetCard();
                setState(() => _isManualMode = true);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildVoiceCard(parsedBib),
          if (_isManualMode && parsedBib != null) ...[
            const SizedBox(height: AppSpacing.md),
            ManualConfirmRow(
              bib: parsedBib,
              flag: _ctrl.flagFor(parsedBib),
              onReRecord: _resetCard,
              onConfirm: () {
                _ctrl.addBib(parsedBib);
                _resetCard();
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
  }

  Color _cardBorderColor(int? parsedBib) {
    if (_hasPendingBib || _isManualMode) {
      if (parsedBib == null) return AppColors.borderColor;
      final flag = _ctrl.flagFor(parsedBib);
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

  Widget _buildVoiceCard(int? parsedBib) {
    return AnimatedContainer(
      duration: AppAnimations.standard,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: _cardBorderColor(parsedBib), width: 1.5),
      ),
      child: VoiceCardContent(
        isListening: _ctrl.isListening,
        isProcessing: _ctrl.isProcessing,
        bars: _bars,
        isManualMode: _isManualMode,
        hasPendingBib: _hasPendingBib,
        bibController: _cardBibController,
        focusNode: _cardBibFocusNode,
        onFieldChanged: _onFieldChanged,
        onFieldSubmitted: _onFieldSubmitted,
        flagFor: (bib) => _ctrl.flagFor(bib),
        runnerFor: _ctrl.runnerFor,
      ),
    );
  }

  Widget _buildList() {
    final entries = _ctrl.entries;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('\uD83C\uDFC1', style: TextStyle(fontSize: 32)),
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
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        return SwipeBibRowWidget(
          key: ValueKey(entry.id),
          entry: entry,
          position: entries.length - i,
          controller: _ctrl,
          isNew: false,
        );
      },
    );
  }
}
