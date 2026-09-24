import '../../../shared/models/race_stage.dart';
import 'race_steps_bar.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';
import '../controller/race_form_state.dart';

Color _getStatusColor(String flowState) {
  switch (flowState) {
    case Race.FLOW_SETUP:
      return AppColors.statusSetup;
    case Race.FLOW_SETUP_COMPLETED:
    case Race.FLOW_PRE_RACE:
      return AppColors.statusPreRace;
    case Race.FLOW_PRE_RACE_COMPLETED:
    case Race.FLOW_POST_RACE:
      return AppColors.statusPostRace;
    case Race.FLOW_FINISHED:
      return AppColors.statusFinished;
    default:
      return AppColors.lightColor;
  }
}

class RaceHeader extends StatefulWidget {
  final RaceScreenController controller;

  const RaceHeader({
    super.key,
    required this.controller,
  });

  @override
  State<RaceHeader> createState() => _RaceHeaderState();
}

class _RaceHeaderState extends State<RaceHeader> {
  late FocusNode _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus &&
          widget.controller.form.isEditing(RaceField.name)) {
        if (!mounted) return;
        if (!_isSetupFlow(widget.controller.flowState)) {
          widget.controller.saveAllChanges(context);
        }
      }
    });
  }

  bool _isSetupFlow(String? flowState) {
    return flowState == Race.FLOW_SETUP || flowState == Race.FLOW_SETUP_COMPLETED;
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final race = widget.controller.race;
    final canEdit = widget.controller.canEdit;
    final flowState = race.flowState ?? Race.FLOW_SETUP;
    final statusColor = _getStatusColor(flowState);
    final stage = RaceStage.of(flowState);
    final isFinished = stage.isFinished;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Race title (editable), with the whole width to itself.
          _buildTitle(race, canEdit),
          if (!isFinished) ...[
            const SizedBox(height: AppSpacing.md),
            RaceStepsBar(stage: stage, color: statusColor),
            const SizedBox(height: AppSpacing.md),
            _ActionButton(
              text: stage.action!,
              color: statusColor,
              onPressed: () => widget.controller.continueRaceFlow(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, thickness: 1, color: AppColors.lightColor),
        ],
      ),
    );
  }

  Widget _buildTitle(Race race, bool canEdit) {
    if (widget.controller.form.isEditing(RaceField.name)) {
      return TextField(
        controller: widget.controller.form.nameController,
        focusNode: _titleFocusNode,
        style: AppTypography.titleLarge.copyWith(
          color: AppColors.darkColor,
        ),
        textAlign: TextAlign.start,
        cursorColor: AppColors.primaryColor,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (value) =>
            widget.controller.trackFieldChange(RaceField.name),
        onSubmitted: (_) =>
            widget.controller.form.stopEditing(RaceField.name),
        onTapOutside: (_) => _titleFocusNode.unfocus(),
      );
    }
    return GestureDetector(
      onTap: canEdit
          ? () {
              widget.controller.form.startEditing(RaceField.name);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _titleFocusNode.requestFocus();
              });
            }
          : null,
      child: Text(
        race.raceName?.isEmpty == true
            ? 'Tap to set race name'
            : race.raceName ?? '',
        style: AppTypography.titleLarge.copyWith(
          color: (race.raceName?.isEmpty == true)
              ? AppColors.lightColor
              : AppColors.darkColor,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.text,
    required this.color,
    required this.onPressed,
  });

  final String text;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // The race's one next step, as wide as the screen so it cannot be
    // missed. Amber is too light for white text, so the words go dark on it.
    final onColor = widget.color.computeLuminance() > 0.5
        ? AppColors.darkColor
        : Colors.white;
    return Semantics(
      button: true,
      label: widget.text,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          curve: AppAnimations.spring,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: _pressed
                ? Color.lerp(widget.color, Colors.black, 0.12)
                : widget.color,
            borderRadius: BorderRadius.circular(AppBorderRadius.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySemibold.copyWith(color: onColor),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.arrow_forward_rounded, color: onColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
