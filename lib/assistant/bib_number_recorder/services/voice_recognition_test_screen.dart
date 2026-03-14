import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/voice_recognition_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_shadows.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Standalone test screen for [VoiceRecognitionService].
///
/// Hold the button to start recording, release to recognise. Requires a real
/// device — simulator microphone is unreliable with Vosk.
///
/// Launch via:
/// ```
/// flutter run -t lib/assistant/bib_number_recorder/services/voice_recognition_smoke_test.dart
/// ```
class VoiceRecognitionTestScreen extends StatefulWidget {
  const VoiceRecognitionTestScreen({super.key});

  @override
  State<VoiceRecognitionTestScreen> createState() =>
      _VoiceRecognitionTestScreenState();
}

enum _Status { initialising, ready, listening, error }

class _VoiceRecognitionTestScreenState
    extends State<VoiceRecognitionTestScreen> {
  final _service = VoiceRecognitionService();

  _Status _status = _Status.initialising;
  String _statusMessage = 'Downloading model…';
  String _partial = '';
  int? _lastBib;
  bool _buttonPressed = false;
  final List<int> _history = [];

  StreamSubscription<int?>? _bibSub;
  StreamSubscription<String>? _partialSub;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    final result = await _service.initialize();
    if (!mounted) return;

    switch (result) {
      case Success():
        _bibSub = _service.bibNumbers.listen(_onBib);
        _partialSub = _service.partialResults.listen(_onPartial);
        setState(() {
          _status = _Status.ready;
          _statusMessage = 'Ready';
        });
      case Failure(:final error):
        setState(() {
          _status = _Status.error;
          _statusMessage = error.userMessage;
        });
    }
  }

  void _onBib(int? bib) {
    if (!mounted) return;
    setState(() {
      _lastBib = bib;
      _partial = '';
      if (bib != null) _history.insert(0, bib);
      if (_history.length > 10) _history.removeLast();
    });
  }

  void _onPartial(String partial) {
    if (!mounted) return;
    setState(() => _partial = partial);
  }

  Future<void> _onButtonDown(_) async {
    if (_status != _Status.ready) return;
    setState(() {
      _buttonPressed = true;
      _status = _Status.listening;
      _partial = '';
      _lastBib = null;
    });
    await _service.start();
  }

  Future<void> _onButtonUp(_) async => _stopListening();

  Future<void> _onButtonCancel() async => _stopListening();

  Future<void> _stopListening() async {
    if (_status != _Status.listening) return;
    setState(() {
      _buttonPressed = false;
      _status = _Status.ready;
    });
    await _service.stop();
  }

  @override
  void dispose() {
    _bibSub?.cancel();
    _partialSub?.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.navBarColor,
        title: Text(
          'Voice Bib Recognition Test',
          style: AppTypography.titleSemibold.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _StatusBanner(status: _status, message: _statusMessage),
            Expanded(child: _RecognitionDisplay(partial: _partial, lastBib: _lastBib)),
            _HistoryRow(history: _history),
            _HoldToSpeakButton(
              status: _status,
              pressed: _buttonPressed,
              onDown: _onButtonDown,
              onUp: _onButtonUp,
              onCancel: _onButtonCancel,
            ),
            SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.message});

  final _Status status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _Status.initialising => AppColors.mediumColor,
      _Status.ready => const Color(0xFF4CAF50),
      _Status.listening => AppColors.primaryColor,
      _Status.error => AppColors.redColor,
    };

    return AnimatedContainer(
      duration: AppAnimations.standard,
      curve: AppAnimations.spring,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: color.withValues(alpha: AppOpacity.light),
      child: Row(
        children: [
          if (status == _Status.initialising)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: AppSpacing.lg,
                height: AppSpacing.lg,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              ),
            ),
          Text(
            message,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _RecognitionDisplay extends StatelessWidget {
  const _RecognitionDisplay({required this.partial, required this.lastBib});

  final String partial;
  final int? lastBib;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Real-time partial text
          AnimatedSwitcher(
            duration: AppAnimations.fast,
            child: partial.isNotEmpty
                ? Text(
                    partial,
                    key: ValueKey(partial),
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                    ),
                    textAlign: TextAlign.center,
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: AppSpacing.xl),
          // Recognised bib number
          AnimatedSwitcher(
            duration: AppAnimations.standard,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: lastBib != null
                ? Text(
                    '$lastBib',
                    key: ValueKey(lastBib),
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.primaryColor,
                      fontSize: 80,
                    ),
                  )
                : Text(
                    '—',
                    key: const ValueKey('empty'),
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.lightColor,
                      fontSize: 80,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.history});

  final List<int> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent',
            style: AppTypography.caption.copyWith(
              color: AppColors.mediumColor,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: history
                .map(
                  (bib) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor
                          .withValues(alpha: AppOpacity.faint),
                      borderRadius:
                          BorderRadius.circular(AppBorderRadius.full),
                      boxShadow: AppShadows.low,
                    ),
                    child: Text(
                      '$bib',
                      style: AppTypography.bodyRegular.copyWith(
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _HoldToSpeakButton extends StatelessWidget {
  const _HoldToSpeakButton({
    required this.status,
    required this.pressed,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
  });

  final _Status status;
  final bool pressed;
  final GestureTapDownCallback onDown;
  final GestureTapUpCallback onUp;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isEnabled = status == _Status.ready || status == _Status.listening;
    final isListening = status == _Status.listening;

    return GestureDetector(
      onTapDown: isEnabled ? onDown : null,
      onTapUp: isEnabled ? onUp : null,
      onTapCancel: isEnabled ? onCancel : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        width: isListening ? 140 : 120,
        height: isListening ? 140 : 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? (isListening
                  ? AppColors.primaryColor
                  : AppColors.primaryColor.withValues(alpha: AppOpacity.solid))
              : AppColors.lightColor,
          boxShadow: isListening ? AppShadows.high : AppShadows.low,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isListening ? 1.2 : 1.0,
              duration: AppAnimations.fast,
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: isEnabled ? Colors.white : AppColors.mediumColor,
                size: 36,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              isListening ? 'Release' : 'Hold',
              style: AppTypography.caption.copyWith(
                color: isEnabled ? Colors.white : AppColors.mediumColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
