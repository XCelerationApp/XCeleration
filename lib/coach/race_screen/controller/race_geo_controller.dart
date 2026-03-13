import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:xceleration/core/utils/logger.dart';
import '../../../core/components/dialog_utils.dart';
import '../../../core/services/geo_location_service.dart';
import 'race_form_state.dart';

/// Owns geolocation state and the logic for populating the location field
/// from the device's current position.
class RaceGeoController extends ChangeNotifier {
  bool isLocationButtonVisible = true;

  final IGeoLocationService _geoLocationService;
  final RaceFormState form;

  RaceGeoController({
    required IGeoLocationService geoLocationService,
    required this.form,
  }) : _geoLocationService = geoLocationService;

  /// Requests the device's current position and populates [form.locationController].
  Future<void> getCurrentLocation(BuildContext context) async {
    try {
      LocationPermission permission =
          await _geoLocationService.checkPermission();
      if (!context.mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await _geoLocationService.requestPermission();
        if (!context.mounted) return;
      }

      if (permission == LocationPermission.deniedForever) {
        DialogUtils.showErrorDialog(context,
            message: 'Location permissions are permanently denied');
        return;
      }

      if (permission == LocationPermission.denied) {
        DialogUtils.showErrorDialog(context,
            message: 'Location permissions are denied');
        return;
      }

      bool locationEnabled =
          await _geoLocationService.isLocationServiceEnabled();
      if (!context.mounted) return;

      if (!locationEnabled) {
        DialogUtils.showErrorDialog(context,
            message: 'Location services are disabled');
        return;
      }

      final position = await _geoLocationService.getCurrentPosition();
      if (!context.mounted) return;

      final placemarks = await _geoLocationService.placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (!context.mounted) return;

      final placemark = placemarks.first;
      form.locationController.text =
          '${placemark.subThoroughfare} ${placemark.thoroughfare}, ${placemark.locality}, ${placemark.administrativeArea} ${placemark.postalCode}';
      form.userLocationController.text = form.locationController.text;
      form.setError(RaceField.location, null);
      updateLocationButtonVisibility();
    } catch (e) {
      Logger.d('Error getting location: $e');
      if (context.mounted) {
        DialogUtils.showErrorDialog(context, message: 'Could not get location');
      }
    }
  }

  void updateLocationButtonVisibility() {
    isLocationButtonVisible = form.locationController.text.trim() !=
        form.userLocationController.text.trim();
    notifyListeners();
  }
}
