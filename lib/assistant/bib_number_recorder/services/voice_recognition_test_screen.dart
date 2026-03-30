import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xceleration/assistant/bib_number_recorder/services/i_voice_recognition_service.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_shadows.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/typography.dart';

/// Hold-to-speak test screen for [VoiceRecognitionService].
///
/// Hold the mic button to record; release to recognise and display the result.
///
/// Launch via:
/// ```
/// flutter run -t lib/assistant/bib_number_recorder/services/voice_recognition_smoke_test.dart
/// ```
class VoiceRecognitionTestScreen extends StatefulWidget {
  const VoiceRecognitionTestScreen({required this.service, super.key});

  final IVoiceRecognitionService service;

  @override
  State<VoiceRecognitionTestScreen> createState() =>
      _VoiceRecognitionTestScreenState();
}

enum _Status { initialising, ready, recording, recognising, error }

class _VoiceRecognitionTestScreenState
    extends State<VoiceRecognitionTestScreen> {
  IVoiceRecognitionService get _service => widget.service;

  _Status _status = _Status.initialising;
  String _statusMessage = 'Initialising…';
  String _rawText = '';
  String? _lastBib;
  final List<String> _history = [];

  StreamSubscription<String?>? _bibSub;
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
          _statusMessage = 'Hold to record';
        });
      case Failure(:final error):
        setState(() {
          _status = _Status.error;
          _statusMessage = error.userMessage;
        });
    }
  }

  void _onPointerDown(_) {
    if (_status != _Status.ready) return;
    setState(() {
      _status = _Status.recording;
      _statusMessage = 'Recording…';
      _rawText = '';
      _lastBib = null;
    });
    _service.start();
  }

  void _onPointerUp(_) => _stopAndRecognise();
  void _onPointerCancel(_) => _stopAndRecognise();

  Future<void> _stopAndRecognise() async {
    if (_status != _Status.recording) return;
    setState(() {
      _status = _Status.recognising;
      _statusMessage = 'Recognising…';
    });
    await _service.stop();
    if (!mounted) return;
    setState(() {
      _status = _Status.ready;
      _statusMessage = 'Hold to record';
    });
  }

  void _onBib(String? bib) {
    if (!mounted) return;
    setState(() {
      _lastBib = bib;
      if (bib != null) {
        _history.insert(0, bib);
        if (_history.length > 10) _history.removeLast();
      }
    });
  }

  void _onPartial(String text) {
    if (!mounted) return;
    setState(() => _rawText = text);
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
          'Voice Bib Test',
          style: AppTypography.titleSemibold.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusCard(status: _status, message: _statusMessage),
              SizedBox(height: AppSpacing.xl),

              Center(
                child: _MicButton(
                  status: _status,
                  onPointerDown: _onPointerDown,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                ),
              ),
              SizedBox(height: AppSpacing.xl),

              _ResultCard(rawText: _rawText, bib: _lastBib),
              SizedBox(height: AppSpacing.xl),

              if (_history.isNotEmpty) ...[
                Text(
                  'History',
                  style: AppTypography.bodySemibold
                      .copyWith(color: AppColors.darkColor),
                ),
                SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: _history
                      .map((bib) => Chip(label: Text(bib)))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.message});
  final _Status status;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _Status.initialising || _Status.recognising => AppColors.mediumColor,
      _Status.ready => AppColors.statusFinished,
      _Status.recording => AppColors.primaryColor,
      _Status.error => AppColors.redColor,
    };
    final isSpinning =
        status == _Status.initialising || status == _Status.recognising;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.light),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
      ),
      child: Row(
        children: [
          if (isSpinning)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.rawText, required this.bib});
  final String rawText;
  final String? bib;

  @override
  Widget build(BuildContext context) {
    if (rawText.isEmpty && bib == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.lightColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
              color: AppColors.mediumColor.withValues(alpha: AppOpacity.strong)),
        ),
        child: Text(
          'No result yet',
          style: AppTypography.caption.copyWith(color: AppColors.mediumColor),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: AppOpacity.faint),
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border:
            Border.all(color: AppColors.primaryColor.withValues(alpha: AppOpacity.medium)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transcript:',
            style:
                AppTypography.caption.copyWith(color: AppColors.mediumColor),
          ),
          Text(
            rawText.isEmpty ? '(empty)' : '"$rawText"',
            style: AppTypography.bodyRegular,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'Bib:',
            style:
                AppTypography.caption.copyWith(color: AppColors.mediumColor),
          ),
          Text(
            bib ?? 'not recognised',
            style: AppTypography.titleSemibold.copyWith(
              color:
                  bib != null ? AppColors.primaryColor : AppColors.redColor,
              fontSize: 40,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.status,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final _Status status;
  final PointerDownEventListener onPointerDown;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  Widget build(BuildContext context) {
    final isRecording = status == _Status.recording;
    final isEnabled = status == _Status.ready || status == _Status.recording;

    return Listener(
      onPointerDown: isEnabled ? onPointerDown : null,
      onPointerUp: isEnabled ? onPointerUp : null,
      onPointerCancel: isEnabled ? onPointerCancel : null,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        width: isRecording ? 140 : 120,
        height: isRecording ? 140 : 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? (isRecording
                  ? AppColors.primaryColor
                  : AppColors.primaryColor.withValues(alpha: AppOpacity.solid))
              : AppColors.lightColor,
          boxShadow: isRecording ? AppShadows.high : AppShadows.low,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isRecording ? 1.2 : 1.0,
              duration: AppAnimations.fast,
              child: Icon(
                isRecording ? Icons.mic : Icons.mic_none,
                color: isEnabled ? Colors.white : AppColors.mediumColor,
                size: 36,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              isRecording ? 'Release' : 'Hold',
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
