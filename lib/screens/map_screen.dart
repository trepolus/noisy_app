import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../services/poi_service.dart';
import '../widgets/custom_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final POIService _poiService = POIService();
  Map<MarkerId, Marker> _markers = {};
  final AudioPlayer _whiteNoisePlayer = AudioPlayer();
  double _currentVolume = 0.0;

  static const double _minVolume = 0.0;
  static const double _maxVolume = 1.0;
  static const double _volumeTriggerRadius = 100.0; // max effect range

  final LatLng _defaultLocation = const LatLng(52.52, 13.405); // Berlin
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Set<MarkerId> _alreadyPlayed = {}; // markers already triggered

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _startLiveLocation();
    _startWhiteNoise();
    _loadPOIs();
  }

  Future<void> _loadPOIs() async {
    await _poiService.loadPOIs();
    _updatePOIMarkers();
  }

  void _updatePOIMarkers() {
    final pois = _poiService.getPOIs();
    setState(() {
      _markers = {
        for (var poi in pois)
          MarkerId(poi.id): Marker(
            markerId: MarkerId(poi.id),
            position: LatLng(poi.latitude, poi.longitude),
            infoWindow: InfoWindow(
              title: poi.name,
              snippet: poi.story,
            ),
          ),
      };
    });
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

  void _startLiveLocation() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen((Position position) async {
      final newLocation = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = newLocation;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newLocation),
      );

      // 🔊 Dynamic white noise volume based on distance to closest POI
      final closestPOI = _poiService.findClosestPOI(
        newLocation.latitude,
        newLocation.longitude,
      );

      if (closestPOI != null) {
        final distance = closestPOI.distanceTo(
          newLocation.latitude,
          newLocation.longitude,
        );

        double volume = 0.0;
        if (distance <= _volumeTriggerRadius) {
          volume = 1.0 - (distance / _volumeTriggerRadius);
          volume = volume.clamp(_minVolume, _maxVolume);
        }

        if ((_currentVolume - volume).abs() > 0.01) {
          _currentVolume = volume;
          await _whiteNoisePlayer.setVolume(_currentVolume);
        }

        // Check if we're close enough to trigger the story
        if (distance <= closestPOI.triggerRadius && 
            !_alreadyPlayed.contains(MarkerId(closestPOI.id))) {
          _showStoryDialog(closestPOI);
          _alreadyPlayed.add(MarkerId(closestPOI.id));
        }
      } else {
        if (_currentVolume > 0) {
          _currentVolume = 0;
          await _whiteNoisePlayer.setVolume(0);
        }
      }
    });
  }

  void _showStoryDialog(POI poi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(poi.name),
        content: Text(poi.story ?? 'No story available for this location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleMapTap(LatLng latLng) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New POI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'POI Name',
                hintText: 'Enter a name for this location',
              ),
              onSubmitted: (name) async {
                if (name.isNotEmpty) {
                  final poi = POI(
                    id: 'poi_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    latitude: latLng.latitude,
                    longitude: latLng.longitude,
                  );
                  await _poiService.addPOI(poi);
                  _updatePOIMarkers();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _startWhiteNoise() async {
    await _whiteNoisePlayer.setReleaseMode(ReleaseMode.loop);
    await _whiteNoisePlayer.setVolume(0.0);
    await _whiteNoisePlayer.play(AssetSource('sounds/white_noise.mp3'));
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng mapCenter = _currentLocation ?? _defaultLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leiwande Location'),
        backgroundColor: Colors.deepPurple,
      ),
      body: CustomMap(
        initialPosition: mapCenter,
        markers: _markers.values.toSet().union({
          if (_currentLocation != null)
            Marker(
              markerId: const MarkerId('user_location'),
              position: _currentLocation!,
              infoWindow: const InfoWindow(title: "You are here"),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
            ),
        }),
        onMapCreated: (controller) => _mapController = controller,
        onTap: _handleMapTap,
      ),
    );
  }
}
