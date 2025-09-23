import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/components/dialog_utils.dart';
import 'package:xceleration/core/services/sync_service.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import 'package:xceleration/core/utils/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  final String currentRole;

  const SettingsScreen({
    super.key,
    required this.currentRole,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _syncMode;
  bool _isLoadingSyncMode = true;

  @override
  void initState() {
    super.initState();
    _loadSyncMode();
  }

  Future<void> _loadSyncMode() async {
    try {
      final mode = await SyncService.instance.getSyncMode();
      if (mounted) {
        setState(() {
          _syncMode = mode;
          _isLoadingSyncMode = false;
        });
      }
    } catch (e) {
      // If there's an error loading, default to off
      if (mounted) {
        setState(() {
          _syncMode = SyncService.syncModeOff;
          _isLoadingSyncMode = false;
        });
      }
    }
  }

  Future<void> _toggleSync(bool enabled) async {
    // Prevent toggling while loading
    if (_isLoadingSyncMode) return;

    final newMode =
        enabled ? SyncService.syncModeAuthenticated : SyncService.syncModeOff;
    await SyncService.instance.setSyncMode(newMode);
    setState(() {
      _syncMode = newMode;
    });

    if (enabled && mounted) {
      DialogUtils.showSuccessDialog(context,
          message: 'Sync enabled. Data will sync when you sign in.');
    }
  }

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
              // Development Tools Section (only in debug mode)
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Development Tools'),
                _buildDevelopmentTools(context),
                const SizedBox(height: 24),
                _buildSectionHeader('Account Settings'),
                _buildChangePasswordButton(context),
              ],
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

  Widget _buildDevelopmentTools(BuildContext context) {
    return Column(
      children: [
        _buildSyncToggle(context),
        const SizedBox(height: 8),
        _buildRoleItem(
          context,
          'Sync Now',
          'Push and pull data with the remote database',
          Icons.sync,
          isSelected: false,
          onTap: () async {
            await DialogUtils.executeWithLoadingDialog(context,
                loadingMessage: 'Please wait...', operation: () async {
              await SyncService.instance.syncAll();
            });
          },
        ),
        _buildRoleItem(
          context,
          'Delete Local Database',
          'Remove the local SQLite DB. It will be recreated on next launch.',
          Icons.delete_forever,
          isSelected: false,
          onTap: () async {
            final confirmed = await DialogUtils.showConfirmationDialog(
              context,
              title: 'Delete local database?',
              content:
                  'This will permanently remove all local data on this device. Continue?',
              confirmText: 'Delete',
              cancelText: 'Cancel',
            );
            if (!confirmed || !context.mounted) return;

            await DialogUtils.executeWithLoadingDialog(context,
                loadingMessage: 'Deleting local database...',
                operation: () async {
              await DatabaseHelper.instance.deleteDatabase();
            });

            if (!context.mounted) return;
            DialogUtils.showSuccessDialog(
              context,
              message: 'Local database deleted.',
            );
          },
        ),
      ],
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

  Widget _buildSyncToggle(BuildContext context) {
    // Show loading state if still loading
    if (_isLoadingSyncMode || _syncMode == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.cloud_sync,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Sync',
                    style: AppTypography.bodySemibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Loading sync settings...',
                    style: AppTypography.bodyRegular.copyWith(
                      color: AppColors.mediumColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    final isEnabled = _syncMode == SyncService.syncModeAuthenticated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorUtils.withOpacity(AppColors.primaryColor, 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cloud_sync,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Sync',
                  style: AppTypography.bodySemibold,
                ),
                const SizedBox(height: 2),
                Text(
                  isEnabled
                      ? 'Sync is enabled for authenticated users'
                      : 'Sync is disabled - data stays local only',
                  style: AppTypography.bodyRegular.copyWith(
                    color: AppColors.mediumColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: _toggleSync,
            activeColor: AppColors.primaryColor,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey,
            activeTrackColor: Colors.black, // Added dark border effect
          ),
        ],
      ),
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
}
