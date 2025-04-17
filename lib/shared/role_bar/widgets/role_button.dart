import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/tutorial_manager.dart';
import '../models/role_enums.dart';
import 'role_selector_sheet.dart';

/// A button that displays the current role and allows changing it
class RoleButton extends StatelessWidget {
  /// Current role or profile
  final Role currentRole;
  
  /// Tutorial manager for coach marks
  final TutorialManager tutorialManager;

  const RoleButton({
    required this.currentRole,
    required this.tutorialManager,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => RoleSelectorSheet.showRoleSelection(context, currentRole),
      child: Icon(Icons.person_outline, color: AppColors.darkColor, size: 56),
    );
  }
}
