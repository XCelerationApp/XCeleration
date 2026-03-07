import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';
import '../controller/race_form_state.dart';
import '../widgets/flow_notification.dart';

// Simplified color function
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
    // case Race.FLOW_POST_RACE_COMPLETED:
    case Race.FLOW_FINISHED:
      return AppColors.statusFinished;
    default:
      return AppColors.lightColor;
  }
}

// Simplified icon function
IconData _getStatusIcon(String flowState) {
  switch (flowState) {
    case Race.FLOW_SETUP:
    case Race.FLOW_SETUP_COMPLETED:
      return Icons.settings;
    case Race.FLOW_PRE_RACE:
    case Race.FLOW_PRE_RACE_COMPLETED:
      return Icons.timer;
    case Race.FLOW_POST_RACE:
      return Icons.flag;
    // case Race.FLOW_POST_RACE_COMPLETED:
    case Race.FLOW_FINISHED:
      return Icons.check_circle;
    default:
      return Icons.help;
  }
}

class RaceHeader extends StatefulWidget {
  final RaceController controller;

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
      // Autosave when losing focus outside of setup flow
      if (!_titleFocusNode.hasFocus &&
          widget.controller.form.isEditing(RaceField.name)) {
        if (!mounted) return;
        // Use controller's synchronous flowState instead of async race access
        if (!_isSetupFlow(widget.controller.flowState)) {
          widget.controller.saveAllChanges(context);
        }
      }
    });
  }

  bool _isSetupFlow(String? flowState) {
    return flowState == 'setup' || flowState == 'setup_completed';
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

    return Column(
      children: [
        // Editable race title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: widget.controller.form.isEditing(RaceField.name)
              ? TextField(
                  controller: widget.controller.form.nameController,
                  focusNode: _titleFocusNode,
                  style: AppTypography.titleLarge.copyWith(
                    color: AppColors.primaryColor,
                  ),
                  textAlign: TextAlign.center,
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
                  onTapOutside: (_) {
                    _titleFocusNode.unfocus();
                  },
                )
              : GestureDetector(
                  onTap: canEdit
                      ? () {
                          widget.controller.form.startEditing(RaceField.name);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _titleFocusNode.requestFocus();
                          });
                        }
                      : null,
                  child: Center(
                    child: Text(
                      race.raceName?.isEmpty == true
                          ? 'Tap to set race name'
                          : race.raceName ?? '',
                      style: AppTypography.titleLarge.copyWith(
                        color: (race.raceName?.isEmpty == true)
                            ? AppColors.lightColor
                            : AppColors.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),

        // Only show flow notification for non-finished states
        if (race.flowState != Race.FLOW_FINISHED)
          FlowNotification(
            flowState: race.flowState ?? 'setup',
            color: _getStatusColor(race.flowState ?? 'setup'),
            icon: _getStatusIcon(race.flowState ?? 'setup'),
            continueAction: () => widget.controller.continueRaceFlow(context),
          ),

        const SizedBox.shrink(),
      ],
    );
  }
}
