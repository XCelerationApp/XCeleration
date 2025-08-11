import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../models/role_enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/components/page_route_animations.dart';
import '../../../core/services/auth_service.dart';
import '../../role_screen.dart';

/// Sheet for selecting roles or profiles
class RoleSelectorSheet {
  /// Show a sheet for selecting assistant roles
  static Future<void> showRoleSelection(
    BuildContext context,
    Role currentRole, {
    bool showConfirmation = true,
  }) async {
    // Show only the roles that are NOT the current one
    final roles = Role.values.where((role) => role != currentRole).toList();

    final newRole = await _showRoleSheet(
      context: context,
      roles: roles,
      currentValue: currentRole,
    );

    // Handle selected role
    if (newRole != null && context.mounted) {
      // Skip confirmation if showConfirmation is false
      if (!showConfirmation) {
        _navigateToRoleScreen(context, newRole);
        return;
      }

      // Check if user has disabled the confirmation dialog
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final skipConfirmation =
          prefs.getBool('skip_role_change_confirmation') ?? false;

      if (skipConfirmation) {
        _navigateToRoleScreen(context, newRole);
      } else {
        final result = await _showRoleChangeConfirmation(context);

        // Check if context is still mounted after the async dialog
        if (!context.mounted) return;

        if (result['confirm'] == true) {
          // Save preference if checkbox was checked
          if (result['dontShowAgain'] == true) {
            await prefs.setBool('skip_role_change_confirmation', true);
            if (!context.mounted) return;
          }
          _navigateToRoleScreen(context, newRole);
        }
      }
    }
  }

  /// Generic sheet for selecting a role or profile option
  static Future<Role?> _showRoleSheet({
    required BuildContext context,
    required List<Role> roles,
    required Role currentValue,
  }) async {
    return await sheet(
      context: context,
      title: 'Select New Role',
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8.0),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: roles.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index < roles.length) {
              return _buildRoleListTile(
                context: context,
                role: roles[index],
              );
            }
            return _buildSignOutTile(context);
          },
        ),
      ),
    );
  }

  /// Build a list tile for a role option
  static Widget _buildRoleListTile({
    required BuildContext context,
    required Role role,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(role),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(role.icon, size: 36, color: AppColors.selectedRoleTextColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.displayName,
                      style: AppTypography.bodySemibold,
                    ),
                    Text(
                      role.description,
                      style: AppTypography.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSignOutTile(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await AuthService.instance.signOut();
          if (!context.mounted) return;
          Navigator.of(context).pop();
          Navigator.of(context).pushAndRemoveUntil(
            RolePageRouteAnimation(child: const RoleScreen()),
            (route) => false,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16.0),
          child: Row(
            children: [
              Icon(Icons.logout,
                  size: 28, color: AppColors.selectedRoleTextColor),
              const SizedBox(width: 12),
              Text('Sign out', style: AppTypography.bodySemibold),
            ],
          ),
        ),
      ),
    );
  }

  /// Show role change confirmation dialog with "Don't show again" option
  static Future<Map<String, bool>> _showRoleChangeConfirmation(
      BuildContext context) async {
    bool dontShowAgain = false;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: AppColors.backgroundColor,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              title: Text(
                'Change Role?',
                style: AppTypography.titleSemibold.copyWith(
                  color: AppColors.primaryColor,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to change your role?\nAny unsaved data could be lost.',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(-12, 0),
                        child: Checkbox(
                          value: dontShowAgain,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (bool? value) {
                            setState(() {
                              dontShowAgain = value ?? false;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              dontShowAgain = !dontShowAgain;
                            });
                          },
                          child: Text(
                            "Don't show this message to me again",
                            style: AppTypography.bodyRegular.copyWith(
                              color: AppColors.mediumColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Stay', style: AppTypography.buttonText),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Continue', style: AppTypography.buttonText),
                ),
              ],
            );
          },
        );
      },
    );

    return {
      'confirm': result ?? false,
      'dontShowAgain': dontShowAgain,
    };
  }

  /// Navigate to the selected role's screen
  static void _navigateToRoleScreen(BuildContext context, Role role) {
    Navigator.of(context).pushAndRemoveUntil(
      RolePageRouteAnimation(child: role.screen),
      (route) => false,
    );
  }
}
