import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/theme/app_border_radius.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import 'package:xceleration/core/theme/app_opacity.dart';
import 'package:xceleration/core/theme/app_spacing.dart';
import 'package:xceleration/core/utils/color_utils.dart';
import '../services/permissions_service.dart';

/// Consolidates all permission-status-to-UI mappings (color, label, action text)
/// into one place, eliminating the parallel conditionals that previously appeared
/// in [_PermissionsDialogState] and [_PermissionRequestButtonState].
class PermissionStatusData {
  final Color color;
  final String label;
  final String actionLabel;

  const PermissionStatusData({
    required this.color,
    required this.label,
    required this.actionLabel,
  });

  static PermissionStatusData from(PermissionStatus status) {
    if (status.isGranted) {
      return PermissionStatusData(
          color: AppColors.statusFinished, label: 'Granted', actionLabel: 'Granted');
    }
    if (status.isPermanentlyDenied) {
      return PermissionStatusData(
          color: AppColors.redColor, label: 'Permanently Denied', actionLabel: 'Settings');
    }
    if (status.isDenied) {
      return PermissionStatusData(
          color: Colors.orange, label: 'Denied', actionLabel: 'Request');
    }
    if (status.isLimited) {
      return PermissionStatusData(
          color: Colors.orange, label: 'Limited', actionLabel: 'Request');
    }
    if (status.isRestricted) {
      return PermissionStatusData(
          color: Colors.grey, label: 'Restricted', actionLabel: 'Request');
    }
    return PermissionStatusData(
        color: Colors.grey, label: 'Unknown', actionLabel: 'Request');
  }
}

/// Dialog that shows the current status of all app permissions
class PermissionsDialog extends StatefulWidget {
  final PermissionsService permissionsService;

  const PermissionsDialog({super.key, required this.permissionsService});

  @override
  State<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  PermissionsService get _permissionsService => widget.permissionsService;
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoading = true;
    });

    final statuses = await _permissionsService.checkAllPermissions();

    if (mounted) {
      setState(() {
        _permissionStatuses = statuses;
        _isLoading = false;
      });
    }
  }

  Widget _buildPermissionTile(Permission permission, PermissionStatus status) {
    final String permissionName =
        _permissionsService.getPermissionName(permission);
    final IconData iconData = _getPermissionIcon(permission);
    final statusData = PermissionStatusData.from(status);

    return ListTile(
      leading: Icon(iconData, color: AppColors.primaryColor),
      title: Text(permissionName),
      subtitle: Text(statusData.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.md,
            height: AppSpacing.md,
            decoration: BoxDecoration(
              color: statusData.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (status.isDenied || status.isPermanentlyDenied)
            ElevatedButton(
              onPressed: () => _requestPermission(permission),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              ),
              child: Text(statusData.actionLabel),
            ),
        ],
      ),
    );
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return Icons.camera_alt;
      case Permission.location:
      case Permission.locationWhenInUse:
      case Permission.locationAlways:
        return Icons.location_on;
      case Permission.bluetooth:
      case Permission.bluetoothScan:
      case Permission.bluetoothConnect:
      case Permission.bluetoothAdvertise:
        return Icons.bluetooth;
      case Permission.storage:
      case Permission.manageExternalStorage:
        return Icons.sd_storage;
      default:
        return Icons.security;
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    // Get the current status (since status is a Future<PermissionStatus>)
    final PermissionStatus status = await permission.status;

    if (status.isPermanentlyDenied) {
      final bool openedSettings =
          await _permissionsService.openSystemSettings();
      if (!openedSettings && mounted) {
        DialogUtils.showErrorDialog(
          context,
          message:
              'Could not open app settings. Please open them manually to grant permissions.',
        );
      }
    } else {
      final bool granted =
          await _permissionsService.requestPermission(permission);

      if (mounted) {
        if (granted) {
          DialogUtils.showMessageDialog(
            context,
            title: 'Success',
            message: 'Permission granted',
          );
        } else {
          DialogUtils.showMessageDialog(
            context,
            title: 'Error',
            message: 'Permission denied',
          );
        }

        // Refresh the status
        _loadPermissions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'App Permissions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadPermissions,
                  tooltip: 'Refresh Permissions',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _permissionStatuses.isEmpty
                    ? const Center(child: Text('No permissions to display'))
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: _permissionStatuses.entries
                              .map((entry) =>
                                  _buildPermissionTile(entry.key, entry.value))
                              .toList(),
                        ),
                      ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A button that can be used to request a specific permission
class PermissionRequestButton extends StatefulWidget {
  final Permission permission;
  final String label;
  final IconData icon;
  final VoidCallback? onGranted;
  final VoidCallback? onDenied;
  final bool showStatus;
  final PermissionsService permissionsService;

  const PermissionRequestButton({
    super.key,
    required this.permission,
    required this.label,
    required this.icon,
    required this.permissionsService,
    this.onGranted,
    this.onDenied,
    this.showStatus = false,
  });

  @override
  State<PermissionRequestButton> createState() =>
      _PermissionRequestButtonState();
}

class _PermissionRequestButtonState extends State<PermissionRequestButton> {
  PermissionsService get _permissionsService => widget.permissionsService;
  PermissionStatus? _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await widget.permission.status;
    if (mounted) {
      setState(() {
        _status = status;
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_status?.isPermanentlyDenied ?? false) {
        await _permissionsService.openSystemSettings();
      } else {
        final bool granted =
            await _permissionsService.requestPermission(widget.permission);

        if (granted) {
          widget.onGranted?.call();
        } else {
          widget.onDenied?.call();
        }
      }
    } finally {
      if (mounted) {
        await _checkPermissionStatus();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusData =
        _status != null ? PermissionStatusData.from(_status!) : null;

    return ElevatedButton.icon(
      onPressed: (_status?.isGranted ?? false) ? null : _requestPermission,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(widget.icon),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label),
          if (widget.showStatus && statusData != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: ColorUtils.withOpacity(statusData.color, AppOpacity.medium),
                borderRadius: BorderRadius.circular(AppBorderRadius.md),
              ),
              child: Text(
                statusData.actionLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: statusData.color,
                ),
              ),
            ),
          ],
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            ColorUtils.withOpacity(Colors.green, AppOpacity.solid),
        disabledForegroundColor: Colors.white,
      ),
    );
  }
}

/// Show the permissions management dialog
void showPermissionsManager(BuildContext context,
    {PermissionsService? permissionsService}) {
  showDialog(
    context: context,
    builder: (context) => PermissionsDialog(
      permissionsService: permissionsService ?? PermissionsService(),
    ),
  );
}

/// Request a specific permission and return if it was granted
Future<bool> requestPermission(
  BuildContext context,
  Permission permission, {
  String? message,
  PermissionsService? permissionsService,
}) async {
  final PermissionsService service = permissionsService ?? PermissionsService();
  final bool isGranted = await service.isPermissionGranted(permission);

  if (isGranted) {
    return true;
  }

  if (message != null && context.mounted) {
    // ignore: use_build_context_synchronously
    final bool shouldRequest = await DialogUtils.showConfirmationDialog(
      context,
      title: 'Permission Required',
      content: message,
      confirmText: 'Grant Permission',
    );

    if (!shouldRequest) {
      return false;
    }
  }

  return await service.requestPermission(permission);
}
