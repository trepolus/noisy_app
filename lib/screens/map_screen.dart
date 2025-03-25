import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../widgets/custom_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();

  final LatLng _defaultLocation = const LatLng(52.52, 13.405); // Berlin
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
      );
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng mapCenter = _currentLocation ?? _defaultLocation;

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('current_location'),
        position: mapCenter,
        infoWindow: InfoWindow(
          title: _currentLocation != null ? "You are here" : "Default Location",
        ),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Map')),
      body: CustomMap(
        initialPosition: mapCenter,
        markers: markers,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
