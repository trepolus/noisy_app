import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for handling location-related functionality
class LocationService {
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 1,
  );

  /// Gets the current location after checking permissions
  Future<Position> getCurrentLocation() async {
    await _checkAndRequestPermissions();
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation
    );
  }

  /// Starts listening to location updates
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    );
  }

  /// Calculates distance between two points in meters
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Checks and requests location permissions if needed
  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionException("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionException(
        "Location permissions are permanently denied. Please enable them in your device settings.",
      );
    }
  }
}

/// Custom exception for location service issues
class LocationServiceException implements Exception {
  final String message;
  LocationServiceException(this.message);
  @override
  String toString() => 'LocationServiceException: $message';
}

/// Custom exception for location permission issues
class LocationPermissionException implements Exception {
  final String message;
  LocationPermissionException(this.message);
  @override
  String toString() => 'LocationPermissionException: $message';
}
