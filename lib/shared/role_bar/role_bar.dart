import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/tutorial_manager.dart';
import '../../core/components/coach_mark.dart';
import 'widgets/instructions_banner.dart';
import 'widgets/role_button.dart';
import 'models/role_enums.dart';

/// A unified role bar that provides role selection and app settings access
/// This component replaces the previous buildRoleBar function
class RoleBar extends StatelessWidget {
  /// Current role or profile (can be a string, Role enum, or Profile enum)
  final Role currentRole;

  /// Tutorial manager for coach marks
  final TutorialManager tutorialManager;

  /// Creates a role bar with the given current role and tutorial manager
  const RoleBar({
    required this.currentRole,
    required this.tutorialManager,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10, left: 5, right: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 1,
            color: AppColors.darkColor,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopSpacing(context),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Instructions banner
              InstructionsBanner(currentRole: currentRole),
              const Spacer(),
              // Role button with coach mark
              CoachMark(
                id: 'role_bar_tutorial',
                tutorialManager: tutorialManager,
                config: const CoachMarkConfig(
                  title: 'Switch Roles',
                  alignmentX: AlignmentX.left,
                  alignmentY: AlignmentY.bottom,
                  description:
                      'Click here to switch between Coach, Timer, and Bib Recorder roles',
                  icon: Icons.touch_app,
                  type: CoachMarkType.targeted,
                  backgroundColor: Color(0xFF1976D2),
                  elevation: 12,
                ),
                child: RoleButton(
                  currentRole: currentRole,
                  tutorialManager: tutorialManager,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds spacing for the top of the role bar
  Widget _buildTopSpacing(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SizedBox(height: topPadding);
  }

  static Future<void> showInstructionsSheet(
      BuildContext context, Role role) async {
    await InstructionsBanner.showInstructionsSheet(context, role);
  }

  static Future<void> showInstructionsSheetManual(
      BuildContext context, Role role) async {
    await InstructionsBanner.showInstructionsSheetManual(context, role);
  }
}
