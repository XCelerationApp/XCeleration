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
      // Also fires when Return closes the field, since it then loses focus.
      if (!_titleFocusNode.hasFocus && mounted) {
        widget.controller.handleFieldFocusLoss(context, RaceField.name);
      }
    });
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The race screen above rebuilds only when the step changes, so without
    // this the rename pencil marked the title for editing but never drew
    // the text field.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildHeader(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final race = widget.controller.race;
    final canEdit = widget.controller.canEdit;
    final flowState = race.flowState ?? Race.FLOW_SETUP;
    final stage = RaceStage.of(flowState);
    final statusColor = stage.color;
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
            // Once sent, a volunteer may still need it: a phone was missed,
            // swapped for a backup, or the roster changed.
            if (RaceStage.canSendAgain(flowState) &&
                widget.controller.canEditResults)
              Center(
                child: TextButton.icon(
                  onPressed: () => widget.controller.sendRaceAgain(context),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Send race to volunteers again'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mediumColor,
                    textStyle: AppTypography.smallBodySemibold,
                  ),
                ),
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
    // Renamed with the pencil, like the other fields. Tapping the title
    // itself used to start editing, easy to do by accident.
    final unnamed = race.raceName?.isEmpty ?? true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            unnamed ? 'Unnamed race' : race.raceName!,
            style: AppTypography.titleLarge.copyWith(
              color: unnamed ? AppColors.mediumColor : AppColors.darkColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (canEdit) ...[
          IconButton(
            key: const ValueKey('edit_race_name'),
            tooltip: 'Rename race',
            icon: const Icon(Icons.edit,
                color: AppColors.primaryColor, size: 20),
            onPressed: () {
              widget.controller.form.startEditing(RaceField.name);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _titleFocusNode.requestFocus();
              });
            },
          ),
          PopupMenuButton<String>(
            key: const ValueKey('race_menu'),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert, color: AppColors.mediumColor),
            color: Colors.white,
            onSelected: (choice) {
              if (choice == 'delete') widget.controller.deleteRace(context);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline,
                        color: AppColors.redColor, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Delete Race',
                        style: AppTypography.bodyRegular
                            .copyWith(color: AppColors.redColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
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
