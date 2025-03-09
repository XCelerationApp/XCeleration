import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/typography.dart';
import '../../../utils/enums.dart';

/// A reusable widget for displaying device connections 
/// This can be used across different flows that need to show device connection status
Widget deviceConnectionWidget(
  DeviceName currentDevice,
  DeviceType deviceType,
  Map<DeviceName, Map<String, dynamic>> otherDevices, {
  Function? callback,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        // Title
        Row(
          children: [
            Icon(Icons.devices, color: AppColors.primaryColor),
            const SizedBox(width: 12),
            Text(
              'Device Connections',
              style: AppTypography.bodySemibold.copyWith(
                color: AppColors.darkColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Device connection status
        ...otherDevices.entries.map((entry) {
          final deviceName = entry.key;
          final deviceData = entry.value;
          final isConnected = deviceData['connected'] ?? false;
          
          // Skip current device
          if (deviceName == currentDevice) {
            return const SizedBox.shrink();
          }
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isConnected ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getDeviceDisplayName(deviceName),
                        style: AppTypography.bodySemibold.copyWith(
                          color: AppColors.darkColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected 
                          ? 'Connected successfully'
                          : 'Waiting for connection...',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.darkColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (deviceType == DeviceType.advertiserDevice) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Share',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        
        // Refresh button
        if (callback != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => callback(),
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(
                'Refresh Connections',
                style: AppTypography.bodyRegular.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Helper function to get a human-readable name for a device
String getDeviceDisplayName(DeviceName deviceName) {
  switch (deviceName) {
    case DeviceName.coach:
      return "Coach's Device";
    case DeviceName.bibRecorder:
      return "Bib Recorder";
    case DeviceName.raceTimer:
      return "Race Timer";
    default:
      return "Unknown Device";
  }
}
