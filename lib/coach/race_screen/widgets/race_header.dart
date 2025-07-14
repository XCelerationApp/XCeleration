import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/models/database/race.dart';
import '../controller/race_screen_controller.dart';
import '../widgets/flow_notification.dart';
import 'unsaved_changes_bar.dart';

// Simplified color function
Color _getStatusColor(String flowState) {
  switch (flowState) {
    case Race.FLOW_SETUP:
      return Colors.amber;
    case Race.FLOW_SETUP_COMPLETED:
    case Race.FLOW_PRE_RACE:
      return Colors.blue;
    case Race.FLOW_PRE_RACE_COMPLETED:
    case Race.FLOW_POST_RACE:
      return Colors.purple;
    // case Race.FLOW_POST_RACE_COMPLETED:
    case Race.FLOW_FINISHED:
      return Colors.green;
    default:
      return Colors.grey;
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
  const RaceHeader({super.key, required this.controller});

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
          widget.controller.isEditingName &&
          !_isSetupFlow()) {
        widget.controller.saveAllChanges(context);
      }
    });
  }

  bool _isSetupFlow() {
    final flowState = widget.controller.race?.flowState;
    return flowState == 'setup' || flowState == 'setup_completed';
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Editable race title
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: widget.controller.isEditingName
              ? TextField(
                  controller: widget.controller.nameController,
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
                      widget.controller.trackFieldChange('name'),
                  onSubmitted: (_) =>
                      widget.controller.stopEditingField('name'),
                  onTapOutside: (_) {
                    _titleFocusNode.unfocus();
                  },
                )
              : GestureDetector(
                  onTap: widget.controller.canEdit
                      ? () {
                          widget.controller.startEditingField('name');
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _titleFocusNode.requestFocus();
                          });
                        }
                      : null,
                  child: Center(
                    child: Text(
                      widget.controller.race!.raceName!.isEmpty
                          ? 'Tap to set race name'
                          : widget.controller.race!.raceName!,
                      style: AppTypography.titleLarge.copyWith(
                        color: widget.controller.race!.raceName!.isEmpty
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
        if (widget.controller.race!.flowState != Race.FLOW_FINISHED)
          FlowNotification(
            flowState: widget.controller.race!.flowState!,
            color: _getStatusColor(widget.controller.race!.flowState!),
            icon: _getStatusIcon(widget.controller.race!.flowState!),
            continueAction: () => widget.controller.continueRaceFlow(context),
          ),

        // Unsaved changes bar (below flow status)
        UnsavedChangesBar(controller: widget.controller),
      ],
    );
  }
}
