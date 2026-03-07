import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/core/utils/sheet_utils.dart';
import '../../../core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_shadows.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_animations.dart';
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

      if (skipConfirmation || currentRole != Role.coach) {
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: roles.length + 1,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.lg),
          itemBuilder: (context, index) {
            if (index < roles.length) {
              return _RoleListTile(role: roles[index]);
            }
            if (currentValue == Role.coach) {
              return const _SignOutTile();
            } else {
              return const SizedBox.shrink();
            }
          },
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
      barrierColor: Colors.black.withValues(alpha: AppOpacity.solid),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              backgroundColor: AppColors.backgroundColor,
              titlePadding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              contentPadding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
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
                  const SizedBox(height: AppSpacing.lg),
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
              actionsPadding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
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
    if (role == Role.coach || role == Role.spectator) {
      // Enforce sign-in for coach and spectator roles
      if (!AuthService.instance.isSignedIn) {
        Navigator.of(context).push(
          RolePageRouteAnimation(child: const RoleScreen()),
        );
        return;
      }
    }
    Navigator.of(context).pushAndRemoveUntil(
      RolePageRouteAnimation(child: role.screen),
      (route) => false,
    );
  }
}

class _RoleListTile extends StatefulWidget {
  const _RoleListTile({required this.role});

  final Role role;

  @override
  State<_RoleListTile> createState() => _RoleListTileState();
}

class _RoleListTileState extends State<_RoleListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(widget.role),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.primaryColor.withValues(alpha: AppOpacity.faint)
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          boxShadow: AppShadows.low,
        ),
        child: Row(
          children: [
            Icon(
              widget.role.icon,
              size: 36,
              color: AppColors.selectedRoleTextColor,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.role.displayName,
                    style: AppTypography.bodySemibold,
                  ),
                  Text(
                    widget.role.description,
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
    );
  }
}

class _SignOutTile extends StatefulWidget {
  const _SignOutTile();

  @override
  State<_SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends State<_SignOutTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () async {
        await AuthService.instance.signOut();
        if (!context.mounted) return;
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          RolePageRouteAnimation(child: const RoleScreen()),
          (route) => false,
        );
      },
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        curve: AppAnimations.spring,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.redColor.withValues(alpha: AppOpacity.faint)
              : AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(
            color: AppColors.redColor.withValues(alpha: AppOpacity.light),
            width: 1,
          ),
          boxShadow: AppShadows.low,
        ),
        child: Row(
          children: [
            const Icon(Icons.logout, size: 28, color: AppColors.redColor),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Sign out',
              style: AppTypography.bodySemibold.copyWith(
                color: AppColors.redColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
