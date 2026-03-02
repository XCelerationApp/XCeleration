import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

abstract interface class IGeoLocationService {
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<bool> isLocationServiceEnabled();
  Future<Position> getCurrentPosition();
  Future<List<geocoding.Placemark>> placemarkFromCoordinates(
      double lat, double lng);
}

class GeoLocationService implements IGeoLocationService {
  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition();

  @override
  Future<List<geocoding.Placemark>> placemarkFromCoordinates(
          double lat, double lng) =>
      geocoding.placemarkFromCoordinates(lat, lng);
}
