import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/permissions_service.dart';
import '../components/permissions_components.dart';

/// Utility class to simplify permission requests throughout the app
class PermissionsUtils {
  static final PermissionsService _permissionsService = PermissionsService();

  /// Check if a permission is granted
  static Future<bool> hasPermission(Permission permission) async {
    return await _permissionsService.isPermissionGranted(permission);
  }

  /// Request a permission with a user-friendly dialog and optional explanation
  static Future<bool> requestPermission(
    BuildContext context,
    Permission permission, {
    String? title,
    String? message,
    String? buttonText,
    bool showExplanation = true,
  }) async {
    // First check if we already have the permission
    final bool hasPermission =
        await _permissionsService.isPermissionGranted(permission);
    if (hasPermission) {
      return true;
    }

    // Show explanation dialog if message is provided and showExplanation is true
    if (showExplanation && message != null && context.mounted) {
      final bool shouldProceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title ?? 'Permission Required'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Deny'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(buttonText ?? 'Allow'),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldProceed) {
        return false;
      }
    }

    // Request the permission
    return await _permissionsService.requestPermission(permission);
  }

  /// Check and request camera permission
  static Future<bool> requestCameraPermission(BuildContext context,
      {String? message}) async {
    return await requestPermission(
      context,
      Permission.camera,
      title: 'Camera Permission',
      message: message ??
          'Camera access is needed to scan QR codes and take photos.',
      buttonText: 'Allow Camera Access',
    );
  }

  /// Check and request location permission
  static Future<bool> requestLocationPermission(BuildContext context,
      {String? message}) async {
    return await requestPermission(
      context,
      Permission.location,
      title: 'Location Permission',
      message: message ??
          'Location access is needed for race mapping and tracking features.',
      buttonText: 'Allow Location Access',
    );
  }

  /// Check and request Nearby Wi-Fi Devices permission for device connections
  static Future<bool> requestNearbyWifiDevicesPermission(BuildContext context,
      {String? message}) async {
    return await requestPermission(
      context,
      Permission.nearbyWifiDevices,
      title: 'Connection Permission',
      message: message ??
          'Nearby Wi-Fi device access is needed for connecting to other devices.',
      buttonText: 'Allow',
    );
  }

  /// Get a map of all app permissions and their current status
  static Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    return await _permissionsService.checkAllPermissions();
  }

  /// Check if a specific permission is permanently denied
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// Get a simple string representation of the permission status
  static String getStatusText(PermissionStatus status) {
    if (status.isGranted) return 'Granted';
    if (status.isDenied) return 'Denied';
    if (status.isPermanentlyDenied) return 'Permanently Denied';
    if (status.isLimited) return 'Limited';
    if (status.isRestricted) return 'Restricted';
    return 'Unknown';
  }

  /// Show the permissions manager dialog
  static void showPermissionsManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PermissionsDialog(),
    );
  }
}
