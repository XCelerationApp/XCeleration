import 'package:flutter/material.dart';
import 'package:xceleration/shared/models/database/master_race.dart';
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
  late final MasterRace masterRace;
  RaceHeader({super.key, required this.controller}) {
    masterRace = controller.masterRace;
  }

  @override
  State<RaceHeader> createState() => _RaceHeaderState();
}

class _RaceHeaderState extends State<RaceHeader> {
  late FocusNode _titleFocusNode;

  @override
  void initState() {
    super.initState();
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() async {
      // Autosave when losing focus outside of setup flow
      if (!_titleFocusNode.hasFocus && widget.controller.isEditingName) {
        final race = await widget.masterRace.race;
        if (!mounted) return;
        if (!_isSetupFlow(race.flowState)) {
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
    return FutureBuilder(
      future: Future.wait([
        widget.masterRace.race,
        widget.controller.canEdit,
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final race = snapshot.data![0] as Race;
        final canEdit = snapshot.data![1] as bool;

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
                      onTap: canEdit
                          ? () {
                              widget.controller.startEditingField('name');
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _titleFocusNode.requestFocus();
                              });
                            }
                          : null,
                      child: Center(
                        child: Text(
                          race.raceName!.isEmpty
                              ? 'Tap to set race name'
                              : race.raceName!,
                          style: AppTypography.titleLarge.copyWith(
                            color: race.raceName!.isEmpty
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
                flowState: race.flowState!,
                color: _getStatusColor(race.flowState!),
                icon: _getStatusIcon(race.flowState!),
                continueAction: () =>
                    widget.controller.continueRaceFlow(context),
              ),

            // Unsaved changes bar (below flow status)
            UnsavedChangesBar(controller: widget.controller),
          ],
        );
      },
    );
  }
}
