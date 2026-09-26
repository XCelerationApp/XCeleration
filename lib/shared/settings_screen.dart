import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/components/dialog_utils.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/utils/logger.dart';
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
    // Timers, Bib Recorders and Spectators never sign in. Syncing, signing
    // out and deleting an account mean nothing to them, and Delete Account
    // used to ask to go ahead and then do nothing.
    final signedIn = AuthService.instance.isSignedIn;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.backgroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          _buildSectionHeader('Account'),
          if (signedIn) ...[
            _buildNote(
                'Signed in as ${AuthService.instance.currentEmail ?? 'a coach'}'),
            _buildSyncNowButton(context),
            if (kDebugMode) _buildChangePasswordButton(context),
            _buildSignOutButton(context),
            _buildDeleteAccountButton(context),
          ] else
            _buildNote('Not signed in. Coaches sign in to keep their races '
                'and runners in the cloud. Timers, Bib Recorders and '
                'Spectators do not need an account.'),
          const SizedBox(height: 24),
          _buildSectionHeader('About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return _buildNote(info == null
                  ? 'XCeleration'
                  : 'XCeleration ${info.version} (${info.buildNumber})');
            },
          ),
          // The App Store expects the privacy policy to be reachable from
          // inside the app, not only from its listing.
          _buildLinkItem(context, 'Privacy Policy', 'What the app keeps and why',
              Icons.privacy_tip_outlined, AppConstants.privacyPolicyUrl),
          _buildLinkItem(context, 'Terms of Service', 'The terms of using the app',
              Icons.description_outlined, AppConstants.termsUrl),
          _buildLinkItem(context, 'Help & Support', 'Questions, problems, ideas',
              Icons.help_outline, AppConstants.supportUrl),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLinkItem(BuildContext context, String title, String description,
      IconData icon, String url) {
    return _buildRoleItem(
      context,
      title,
      description,
      icon,
      isSelected: false,
      onTap: () async {
        var opened = false;
        try {
          opened = await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        } catch (e) {
          Logger.e('Could not open $url: $e');
        }
        if (!opened && context.mounted) {
          DialogUtils.showErrorDialog(context,
              message: 'Could not open the page. It is at $url');
        }
      },
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        text,
        style: AppTypography.bodyRegular.copyWith(color: AppColors.mediumColor),
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
      'Save your races to your account and get changes made on your other phones',
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
          Logger.e('Sync failed: $e');
          DialogUtils.showErrorDialog(context,
              message: 'Could not sync. Check you are online and try again.');
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
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        final userId = AuthService.instance.currentUserId;
        if (userId == null) return;
        try {
          await DialogUtils.executeWithLoadingDialog(context,
              loadingMessage: 'Deleting account...', operation: () async {
            await AuthService.instance.deleteCurrentUserAccount();
          });
          if (!context.mounted) return;
          // The account is gone from the server; the races must not stay on
          // the phone, where the next person to sign in would find them.
          await ServiceLocator.get<IDatabaseConnectionProvider>()
              .deleteUserData(userId);
          await AuthService.instance.signOut();
          if (!context.mounted) return;
          DialogUtils.showSuccessDialog(context, message: 'Account deleted');
          Navigator.of(context).pushAndRemoveUntil(
            RolePageRouteAnimation(child: const RoleScreen()),
            (route) => false,
          );
        } catch (e) {
          if (!context.mounted) return;
          Logger.e('Account deletion failed: $e');
          DialogUtils.showErrorDialog(
            context,
            message: 'Could not delete your account. Check you are online '
                'and try again.',
          );
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
        // A cursor belongs to the account that set it, and the database to the
        // user whose races are in it. Both have to go before the next sign-in.
        // Settings is reachable from the assistant and spectator screens too,
        // where the coach database may never have been opened: then there is
        // no cursor to clear, and signing out must still go ahead.
        try {
          await context.read<ISyncService>().clearSyncCursors();
        } on StateError {
          Logger.d('Sign out: no database open, so no sync cursors to clear');
        }
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
