import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xceleration/core/components/dialog_utils.dart';
import 'package:xceleration/core/theme/app_colors.dart';
import '../services/permissions_service.dart';

/// Dialog that shows the current status of all app permissions
class PermissionsDialog extends StatefulWidget {
  const PermissionsDialog({super.key});

  @override
  State<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  final PermissionsService _permissionsService = PermissionsService();
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
    final String permissionName = _permissionsService.getPermissionName(permission);
    final IconData iconData = _getPermissionIcon(permission);
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status);

    return ListTile(
      leading: Icon(iconData, color: AppColors.primaryColor),
      title: Text(permissionName),
      subtitle: Text(statusText),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          if (status.isDenied || status.isPermanentlyDenied)
            ElevatedButton(
              onPressed: () => _requestPermission(permission),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(status.isPermanentlyDenied ? 'Settings' : 'Request'),
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

  Color _getStatusColor(PermissionStatus status) {
    if (status.isGranted) {
      return Colors.green;
    } else if (status.isDenied) {
      return Colors.orange;
    } else if (status.isPermanentlyDenied) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String _getStatusText(PermissionStatus status) {
    if (status.isGranted) {
      return 'Granted';
    } else if (status.isDenied) {
      return 'Denied';
    } else if (status.isPermanentlyDenied) {
      return 'Permanently Denied';
    } else if (status.isLimited) {
      return 'Limited';
    } else if (status.isRestricted) {
      return 'Restricted';
    } else {
      return 'Unknown';
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    // Get the current status (since status is a Future<PermissionStatus>)
    final PermissionStatus status = await permission.status;
    
    if (status.isPermanentlyDenied) {
      final bool openedSettings = await _permissionsService.openSystemSettings();
      if (!openedSettings && mounted) {
        DialogUtils.showErrorDialog(
          context,
          message: 'Could not open app settings. Please open them manually to grant permissions.',
        );
      }
    } else {
      final bool granted = await _permissionsService.requestPermission(permission);
      
      if (mounted) {
        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission granted'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied'),
              backgroundColor: Colors.red,
            ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 16),
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
                              .map((entry) => _buildPermissionTile(entry.key, entry.value))
                              .toList(),
                        ),
                      ),
            const SizedBox(height: 16),
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

  const PermissionRequestButton({
    super.key,
    required this.permission,
    required this.label,
    required this.icon,
    this.onGranted,
    this.onDenied,
    this.showStatus = false,
  });

  @override
  State<PermissionRequestButton> createState() => _PermissionRequestButtonState();
}

class _PermissionRequestButtonState extends State<PermissionRequestButton> {
  final PermissionsService _permissionsService = PermissionsService();
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
        final bool granted = await _permissionsService.requestPermission(widget.permission);
        
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
    final bool isGranted = _status?.isGranted ?? false;
    final bool isPermanentlyDenied = _status?.isPermanentlyDenied ?? false;
    
    return ElevatedButton.icon(
      onPressed: isGranted ? null : _requestPermission,
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
          if (widget.showStatus && _status != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isGranted
                    ? Colors.green.withOpacity(0.2)
                    : isPermanentlyDenied
                        ? Colors.red.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isGranted
                    ? 'Granted'
                    : isPermanentlyDenied
                        ? 'Settings'
                        : 'Request',
                style: TextStyle(
                  fontSize: 10,
                  color: isGranted
                      ? Colors.green
                      : isPermanentlyDenied
                          ? Colors.red
                          : Colors.orange,
                ),
              ),
            ),
          ],
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.green.withOpacity(0.5),
        disabledForegroundColor: Colors.white,
      ),
    );
  }
}

/// Show the permissions management dialog
void showPermissionsManager(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const PermissionsDialog(),
  );
}

/// Request a specific permission and return if it was granted
Future<bool> requestPermission(
  BuildContext context,
  Permission permission, {
  String? message,
}) async {
  final PermissionsService permissionsService = PermissionsService();
  final bool isGranted = await permissionsService.isPermissionGranted(permission);
  
  if (isGranted) {
    return true;
  }
  
  if (message != null) {
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
  
  return await permissionsService.requestPermission(permission);
}
