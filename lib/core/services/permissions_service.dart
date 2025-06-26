import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// A centralized service to manage all app permissions
class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();

  factory PermissionsService() {
    return _instance;
  }

  PermissionsService._internal();

  /// Map of all permission types with friendly names
  final Map<Permission, String> _permissionNames = {
    Permission.camera: 'Camera',
    Permission.location: 'Location',
    Permission.locationWhenInUse: 'Location When In Use',
    Permission.storage: 'Storage',
    Permission.accessMediaLocation: 'Media Location',
    Permission.nearbyWifiDevices: 'Nearby Wi-Fi Devices',
  };

  /// Get all permission types used by the app
  List<Permission> get allPermissions => _permissionNames.keys.toList();

  /// Get a friendly name for a permission
  String getPermissionName(Permission permission) {
    return _permissionNames[permission] ?? 'Unknown';
  }

  /// Check if a single permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Check the status of all permissions
  Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};

    for (var permission in allPermissions) {
      statuses[permission] = await permission.status;
    }

    return statuses;
  }

  /// Request a single permission
  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  /// Request multiple permissions at once
  Future<Map<Permission, PermissionStatus>> requestPermissions(
      List<Permission> permissions) async {
    return await permissions.request();
  }

  /// Check if location permission is granted using Geolocator
  /// This uses a different approach since Geolocator has its own permission system
  Future<bool> isLocationPermissionGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request location permission using Geolocator
  Future<bool> requestLocationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Open app settings to allow user to enable permissions
  Future<bool> openSystemSettings() async {
    // This is the correct way to call the openAppSettings function from permission_handler
    return await openAppSettings();
  }
}
