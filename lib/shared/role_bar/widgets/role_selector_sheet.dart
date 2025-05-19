import 'package:flutter/material.dart';
import 'package:xceleration/core/theme/typography.dart';
import 'package:xceleration/utils/sheet_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/dialog_utils.dart';
import '../models/role_enums.dart';

/// Sheet for selecting roles or profiles
class RoleSelectorSheet {
  /// Show a sheet for selecting assistant roles
  static Future<void> showRoleSelection(
    BuildContext context, 
    Role currentRole,
  ) async {
    // Show only the roles that are NOT the current one
    final roles = Role.values.where((role) => role != currentRole).toList();
    
    final newRole = await _showRoleSheet(
      context: context,
      roles: roles,
      currentValue: currentRole,
    );
    
    // Handle selected role
    if (newRole != null && context.mounted) {
      final confirmChange = await DialogUtils.showConfirmationDialog(
        context,
        title: 'Change Role?',
        content: 'Are you sure you want to change your role?\nAny unsaved data could be lost.',
        confirmText: 'Continue',
        cancelText: 'Stay',
      );
      
      // Check if context is still mounted after the async dialog
      if (!context.mounted) return;
      
      if (confirmChange) {
        _navigateToRoleScreen(context, newRole);
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
          itemCount: roles.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildRoleListTile(
              context: context,
              role: roles[index],
            );
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
              Icon(role.icon,
                  size: 36,
                  color: AppColors.selectedRoleTextColor),
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
  
  /// Navigate to the selected role's screen
  static void _navigateToRoleScreen(BuildContext context, Role role) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => role.screen),
      (route) => false,
    );
  }
}
