import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/components/dialog_utils.dart';
import 'package:xceleration/core/result.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/repositories/i_database_connection_provider.dart';
import 'package:xceleration/core/services/auth_service.dart';
import 'package:xceleration/core/services/i_sync_service.dart';
import 'package:xceleration/core/services/service_locator.dart';
import '../core/components/page_route_animations.dart';
import 'role_screen.dart';

class SettingsScreen extends StatelessWidget {
  final String currentRole;

  const SettingsScreen({
    super.key,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.backgroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            children: [
                const SizedBox(height: 24),
              _buildSectionHeader('Sync'),
              _buildSyncNowButton(context),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Account Settings'),
                _buildChangePasswordButton(context),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader('Account'),
              _buildDeleteAccountButton(context),
              _buildSignOutButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: AppTypography.titleSemibold.copyWith(
          color: AppColors.darkColor,
        ),
      ),
    );
  }

  Widget _buildRoleItem(
    BuildContext context,
    String title,
    String description,
    IconData icon, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? ColorUtils.withOpacity(AppColors.primaryColor, 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor
                    : ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySemibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Remove selection indicators
            // if (isSelected)
            //   Icon(
            //     Icons.check_circle,
            //     color: AppColors.primaryColor,
            //     size: 24,
            //   )
            // else
            //   Icon(
            //     Icons.circle_outlined,
            //     color: AppColors.mediumColor,
            //     size: 24,
            //   ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncNowButton(BuildContext context) {
    return _buildRoleItem(
      context,
      'Sync Now',
      'Push local changes and pull updates from the cloud',
      Icons.sync,
      isSelected: false,
      onTap: () async {
        final syncService = context.read<ISyncService>();
        bool syncSucceeded = false;
        try {
          await DialogUtils.executeWithLoadingDialog(
            context,
            loadingMessage: 'Syncing...',
            operation: () async {
              await syncService.syncAll();
              syncSucceeded = true;
            },
          );
        } catch (e) {
          if (!context.mounted) return;
          DialogUtils.showErrorDialog(context, message: 'Sync failed: $e');
          return;
        }
        if (!context.mounted) return;
        if (syncSucceeded) {
          DialogUtils.showSuccessDialog(
            context,
            message: 'Done, synced successfully!',
          );
        }
      },
    );
  }

  Widget _buildChangePasswordButton(BuildContext context) {
    return _buildRoleItem(
      context,
      'Change Password',
      'Update your account password',
      Icons.lock,
      isSelected: false,
      onTap: () {
        // Placeholder for change password functionality
        DialogUtils.showMessageDialog(
          context,
          title: 'Information',
          message: 'Change password feature coming soon!',
        );
      },
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return _buildRoleItem(
      context,
      'Delete Account',
      'Permanently delete your account',
      Icons.person_remove_alt_1,
      isSelected: false,
      onTap: () async {
        final confirmed = await DialogUtils.showConfirmationDialog(
          context,
          title: 'Delete Account',
          content:
              'This will permanently delete your account and associated cloud data. Continue?',
          confirmText: 'Delete',
          cancelText: 'Cancel',
        );
        if (!confirmed || !context.mounted) return;
        final result = await DialogUtils.executeWithLoadingDialog(context,
            loadingMessage: 'Deleting account...', operation: () async {
          return AuthService.instance.deleteCurrentUserAccount();
        });
        if (!context.mounted) return;
        switch (result) {
          case Success():
            final userId = AuthService.instance.currentUserId!;
            await ServiceLocator.get<IDatabaseConnectionProvider>().deleteUserData(userId);
            await AuthService.instance.signOut();
            if (!context.mounted) return;
            DialogUtils.showSuccessDialog(context, message: 'Account deleted');
            Navigator.of(context).pushAndRemoveUntil(
              RolePageRouteAnimation(child: const RoleScreen()),
              (route) => false,
            );
          case Failure(:final error):
            DialogUtils.showErrorDialog(context, message: error.userMessage);
          case null:
            break;
        }
      },
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return _buildRoleItem(
      context,
      'Sign Out',
      'Sign out of your account on this device',
      Icons.logout,
      isSelected: false,
      onTap: () async {
        await ServiceLocator.get<IDatabaseConnectionProvider>().close();
        await AuthService.instance.signOut();
        if (!context.mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          RolePageRouteAnimation(child: const RoleScreen()),
          (route) => false,
        );
      },
    );
  }
}
