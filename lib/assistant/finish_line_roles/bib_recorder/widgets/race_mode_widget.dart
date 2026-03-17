import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/controller/bib_recorder_v2_controller.dart';
import 'package:xceleration/assistant/bib_number_recorder/widgets/runners_loaded_sheet.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/overflow_menu_button.dart';
import 'package:xceleration/assistant/finish_line_roles/shared/widgets/confirm_bottom_sheet.dart';
import 'package:xceleration/assistant/finish_line_roles/bib_recorder/widgets/swipe_bib_row_widget.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import 'package:xceleration/shared/models/timing_records/bib_datum.dart';
import 'package:xceleration/core/theme/app_animations.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_shadows.dart';
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
  void initState() {
    super.initState();
  }

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
                _buildHeader(),
                _buildVoiceArea(),
                Expanded(child: _buildList()),
                _buildBottomBar(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _ctrl.selectedRace?.formattedName ?? '',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: AppColors.darkColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _raceStarted
                  ? _LiveBadge()
                  : _NotStartedBadge(),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${_ctrl.entries.length}',
                style: AppTypography.smallBodySemibold.copyWith(
                  color: AppColors.mediumColor,
                ),
              ),
            ],
          ),
        ],
      ),
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
                _buildModeToggle(),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildVoiceCard(parsedBib),
              const SizedBox(height: AppSpacing.md),
              if (_isManualMode && parsedBib != null)
                _buildManualConfirmRow(parsedBib)
              else if (_raceStarted && !_isManualMode)
                _buildMicArea(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              icon: Icons.mic,
              label: 'Voice',
              selected: !_isManualMode,
              onTap: () {
                setState(() {
                  _isManualMode = false;
                  _manualBibController.clear();
                });
              },
            ),
          ),
          Expanded(
            child: _ToggleChip(
              icon: Icons.keyboard_alt_outlined,
              label: 'Manual',
              selected: _isManualMode,
              onTap: () {
                setState(() => _isManualMode = true);
              },
            ),
          ),
        ],
      ),
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
    // Voice mode — colour based on the last auto-added bib.
    final lastEntry = _ctrl.entries.isEmpty ? null : _ctrl.entries.first;
    if (lastEntry != null) {
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
    // In manual mode the card only shows the text field — no bib display.
    final lastEntry =
        (!_isManualMode && _ctrl.entries.isNotEmpty) ? _ctrl.entries.first : null;
    final displayBib = lastEntry?.bib;
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
      child: _buildVoiceCardContent(
        displayBib,
        flag,
        runner,
        parsedManualBib: parsedManualBib,
      ),
    );
  }

  Widget _buildVoiceCardContent(
    int? displayBib,
    String? flag,
    dynamic runner, {
    int? parsedManualBib,
  }) {
    if (_ctrl.isListening) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _bars
            .map(
              (h) => AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor
                      .withValues(alpha: 0.6 + (h / 32) * 0.4),
                  borderRadius:
                      BorderRadius.circular(AppBorderRadius.full),
                ),
              ),
            )
            .toList(),
      );
    }

    if (_ctrl.isProcessing) {
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

    if (_isManualMode) {
      final manualFlag =
          parsedManualBib != null ? _ctrl.flagFor(parsedManualBib) : null;
      final manualRunner =
          parsedManualBib != null ? _ctrl.runnerFor(parsedManualBib) : null;

      return Column(
        children: [
          TextField(
            controller: _manualBibController,
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
              _ctrl.addBib(bib);
              _manualBibController.clear();
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

  Widget _buildManualConfirmRow(int bib) {
    final flag = _ctrl.flagFor(bib);
    final confirmColor = flag == 'duplicate'
        ? AppColors.redColor
        : flag == 'unknown'
            ? AppColors.statusSetup
            : AppColors.primaryColor;

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Re-record',
            color: AppColors.mediumColor,
            backgroundColor: Colors.white,
            borderColor: AppColors.borderColor,
            onTap: () => _manualBibController.clear(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: _ActionButton(
            label: flag != null ? 'Add Anyway' : 'Add #$bib',
            color: Colors.white,
            backgroundColor: confirmColor,
            onTap: () {
              _ctrl.addBib(bib);
              _manualBibController.clear();
            },
          ),
        ),
      ],
    );
  }

  /// Voice-mode input area: mic button centred, Re-record fades in on the left.
  Widget _buildMicArea() {
    const sideWidth = 96.0;
    final hasEntries = _ctrl.entries.isNotEmpty;

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
              child: _ActionButton(
                label: 'Re-record',
                color: AppColors.mediumColor,
                backgroundColor: Colors.white,
                borderColor: AppColors.borderColor,
                onTap: _ctrl.reRecordLast,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _buildMicButton(),
        const SizedBox(width: AppSpacing.md),
        const SizedBox(width: sideWidth),
      ],
    );
  }

  Widget _buildMicButton() {
    return Column(
      children: [
        GestureDetector(
          onPanStart: (_) => _onMicDown(),
          onPanEnd: (_) => _onMicUp(),
          onTapDown: (_) => _onMicDown(),
          onTapUp: (_) => _onMicUp(),
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ctrl.isListening
                  ? AppColors.primaryColor
                  : AppColors.surfaceColor,
              border: Border.all(
                color: _ctrl.isListening
                    ? AppColors.primaryColor
                    : AppColors.borderColor,
                width: 2.5,
              ),
              boxShadow: _ctrl.isListening ? AppShadows.glow : [],
            ),
            child: Icon(
              Icons.mic,
              color: _ctrl.isListening ? Colors.white : AppColors.mediumColor,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _ctrl.isListening ? 'LISTENING…' : 'HOLD TO RECORD',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.mediumColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    // In voice mode the card shows entries[0] — skip it from the list so the
    // bib doesn't appear in both places at once.
    final skipFirst = !_isManualMode && _ctrl.lastAddedBib != null;
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
          isNew: i == 0,
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _raceStarted
                ? _ActionButton(
                    label: 'Stop Race',
                    color: AppColors.redColor,
                    backgroundColor:
                        AppColors.redColor.withValues(alpha: AppOpacity.faint),
                    borderColor:
                        AppColors.redColor.withValues(alpha: AppOpacity.strong),
                    onTap: () => _showStopConfirm(context),
                  )
                : _ActionButton(
                    label: 'Start Race',
                    color: AppColors.statusFinished,
                    backgroundColor: AppColors.statusFinished
                        .withValues(alpha: AppOpacity.light),
                    borderColor: AppColors.statusFinished,
                    onTap: _ctrl.beginRace,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OverflowMenuButton(
            items: [
              OverflowMenuItem(
                label: 'View Runners',
                onTap: () => sheet(
                  context: context,
                  title: 'Loaded Runners',
                  body: RunnersLoadedSheet(
                    runners: _ctrl.runners
                        .map((r) => BibDatum(
                              bib: r.bibNumber,
                              name: r.name,
                              teamAbbreviation: r.teamAbbreviation,
                              grade: r.grade,
                              teamColor: r.teamColor,
                            ))
                        .toList(),
                  ),
                ),
              ),
              OverflowMenuItem(
                label: 'Clear All Records',
                danger: true,
                onTap: _ctrl.clearEntries,
              ),
              OverflowMenuItem(
                label: 'Delete Race',
                danger: true,
                onTap: () => _showDeleteConfirm(context),
              ),
              OverflowMenuItem(
                label: 'Leave Race',
                onTap: _ctrl.leaveRace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStopConfirm(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Stop Race?',
        message:
            'Stopping ends recording. You can still edit entries afterward.',
        confirmLabel: 'Stop Race',
        onConfirm: _ctrl.stopRace,
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmBottomSheet(
        title: 'Delete Race?',
        message:
            'Permanently deletes all ${_ctrl.entries.length} bib records.',
        confirmLabel: 'Delete',
        onConfirm: _ctrl.deleteRace,
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.liveBackground,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: AppColors.liveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.redColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Text(
            'LIVE',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.redColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotStartedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.full),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Text(
        'Not Started',
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.mediumColor,
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.backgroundColor ?? widget.color)
                  .withValues(alpha: AppOpacity.solid)
              : widget.backgroundColor ?? widget.color,
          borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          border: widget.borderColor != null
              ? Border.all(color: widget.borderColor!)
              : null,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: AppTypography.smallBodySemibold.copyWith(
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}


class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm - 1,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.darkColor : AppColors.mediumColor,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.darkColor : AppColors.mediumColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

