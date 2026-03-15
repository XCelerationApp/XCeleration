import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_border_radius.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_opacity.dart';
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

String _getStatusText(String flowState) {
  switch (flowState) {
    case Race.FLOW_SETUP:
      return 'Race Setup';
    case Race.FLOW_SETUP_COMPLETED:
      return 'Ready to Share';
    case Race.FLOW_PRE_RACE:
      return 'Sharing Race';
    case Race.FLOW_PRE_RACE_COMPLETED:
      return 'Ready for Results';
    case Race.FLOW_POST_RACE:
      return 'Processing Results';
    case Race.FLOW_FINISHED:
      return 'Race Complete';
    default:
      return flowState;
  }
}

String _getActionButtonText(String flowState) {
  if (flowState == Race.FLOW_SETUP_COMPLETED) return 'Share Race';
  if (flowState == Race.FLOW_PRE_RACE_COMPLETED) return 'Process Results';
  return 'Continue';
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
    final isFinished = flowState == Race.FLOW_FINISHED;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Eyebrow: status dot + label
                    if (!isFinished) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: AppSpacing.sm,
                            height: AppSpacing.sm,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _getStatusText(flowState).toUpperCase(),
                            style: AppTypography.smallBodySemibold.copyWith(
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    // Race title (editable)
                    _buildTitle(race, canEdit),
                    // Subtitle — setup stage only
                    if (flowState == Race.FLOW_SETUP) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Fill in the details to get started',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mediumColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action button — all non-finished states
              if (!isFinished) ...[
                const SizedBox(width: AppSpacing.md),
                _ActionButton(
                  text: _getActionButtonText(flowState),
                  color: statusColor,
                  onPressed: () => widget.controller.continueRaceFlow(context),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.lightColor),
      ],
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
        maxLines: 1,
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: widget.color.withValues(
              alpha: _pressed ? AppOpacity.medium : AppOpacity.light),
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(
            color: widget.color.withValues(alpha: AppOpacity.strong),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: AppTypography.smallBodySemibold.copyWith(
                color: widget.color,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              color: widget.color,
              size: AppSpacing.lg,
            ),
          ],
        ),
      ),
    );
  }
}
