import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/poi.dart';
import '../services/location_service.dart';
import '../services/poi_service.dart';
import '../widgets/custom_map.dart';
import '../widgets/debug_overlay.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controllers
  GoogleMapController? _mapController;
  final AudioPlayer _whiteNoisePlayer = AudioPlayer();
  final AudioPlayer _storyPlayer = AudioPlayer();

  // Services
  final LocationService _locationService = LocationService();
  final POIService _poiService = POIService();

  // State
  Map<MarkerId, Marker> _markers = {};
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  Set<String> _triggeredPOIs = {};
  double _currentVolume = 0.0;
  final List<String> _debugLogs = [];
  bool _isDebugVisible = false;
  bool _isVolumeEnabled = true;

  // Constants
  static const double _minVolume = 0.0;
  static const double _maxVolume = 1.0;
  static const double _volumeTriggerRadius = 100.0;
  static const double _defaultZoomLevel = 14.0;
  static const LatLng _defaultLocation = LatLng(52.52, 13.405); // Berlin

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _addDebugLog("Initializing app...");
    await _initializeAudio();
    await _loadPOIs();
    await _initializeLocation();
    _addDebugLog("App initialization complete");
  }

  // Audio Handling
  Future<void> _initializeAudio() async {
    await _whiteNoisePlayer.setReleaseMode(ReleaseMode.loop);
    await _whiteNoisePlayer.setVolume(0.0);
    await _whiteNoisePlayer.play(AssetSource('sounds/white_noise.mp3'));
  }

  Future<void> _updateWhiteNoiseVolume(double distance) async {
    if (!_isVolumeEnabled) return; // Don't update volume if muted

    double newVolume = 0.0;
    if (distance <= _volumeTriggerRadius) {
      newVolume = 1.0 - (distance / _volumeTriggerRadius);
      newVolume = newVolume.clamp(_minVolume, _maxVolume);
    }

    if ((_currentVolume - newVolume).abs() > 0.01) {
      _currentVolume = newVolume;
      await _whiteNoisePlayer.setVolume(_currentVolume);
      _addDebugLog("Updated white noise volume: $_currentVolume");
    }
  }

  // POI Management
  Future<void> _loadPOIs() async {
    final pois = await _poiService.getPOIs();
    _updatePOIMarkers(pois);
  }

  void _updatePOIMarkers(List<POI> pois) {
    setState(() {
      _markers = {
        for (var poi in pois)
          MarkerId(poi.id): _createMarkerFromPOI(poi),
      };
    });
  }

  Marker _createMarkerFromPOI(POI poi) {
    return Marker(
      markerId: MarkerId(poi.id),
      position: LatLng(poi.latitude, poi.longitude),
      infoWindow: InfoWindow(
        title: poi.name,
        snippet: poi.story,
      ),
    );
  }

  Future<void> _handleNewPOI(String name, LatLng location) async {
    if (name.isEmpty) return;

    final poi = POI(
      id: 'poi_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    await _poiService.addPOI(poi);
    await _loadPOIs();
  }

  // Location Handling
  Future<void> _initializeLocation() async {
    try {
      await _loadCurrentLocation();
      _startLocationTracking();
    } catch (e) {
      _showErrorDialog('Location Error', e.toString());
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      _updateLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      debugPrint("Location error: $e");
      rethrow;
    }
  }

  void _startLocationTracking() {
    _positionStream = _locationService.getLocationStream().listen(
      (Position position) => _handleLocationUpdate(position),
      onError: (error) => _showErrorDialog('Location Error', error.toString()),
    );
  }

  Future<void> _handleLocationUpdate(Position position) async {
    final newLocation = LatLng(position.latitude, position.longitude);
    _updateLocation(newLocation);
    _addDebugLog("Location updated: ${position.latitude}, ${position.longitude}");

    final closestPOI = _poiService.findClosestPOI(
      newLocation.latitude,
      newLocation.longitude,
    );

    if (closestPOI != null) {
      final distance = closestPOI.distanceTo(
        newLocation.latitude,
        newLocation.longitude,
      );

      await _updateWhiteNoiseVolume(distance);
      _addDebugLog("Distance to closest POI (${closestPOI.name}): ${distance.toStringAsFixed(2)}m");

      if (distance <= closestPOI.triggerRadius && 
          !_triggeredPOIs.contains(closestPOI.id)) {
        _showStoryDialog(closestPOI);
        _triggeredPOIs.add(closestPOI.id);
        _addDebugLog("Triggered POI story: ${closestPOI.name}");
      }
    } else {
      await _updateWhiteNoiseVolume(_volumeTriggerRadius);
      _addDebugLog("No POI in range");
    }
  }

  void _updateLocation(LatLng location) {
    setState(() => _currentLocation = location);
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  // UI Elements
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

  void _showAddPOIDialog(LatLng location) {
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
                  await _handleNewPOI(name, location);
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _addDebugLog(String message) {
    setState(() {
      _debugLogs.add("[${DateTime.now().toIso8601String()}] $message");
    });
  }

  void _clearDebugLogs() {
    setState(() {
      _debugLogs.clear();
    });
  }

  void _toggleDebugOverlay() {
    setState(() {
      _isDebugVisible = !_isDebugVisible;
    });
  }

  Future<void> _toggleVolume() async {
    setState(() {
      _isVolumeEnabled = !_isVolumeEnabled;
    });
    if (_isVolumeEnabled) {
      await _whiteNoisePlayer.play(AssetSource('sounds/white_noise.mp3'));
      await _whiteNoisePlayer.setVolume(_currentVolume);
    } else {
      await _whiteNoisePlayer.stop();
    }
    _addDebugLog("Volume ${_isVolumeEnabled ? 'enabled' : 'disabled'}");
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _whiteNoisePlayer.dispose();
    _storyPlayer.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leiwande Location'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(_isVolumeEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleVolume,
            tooltip: 'Toggle sound',
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomMap(
            initialPosition: _currentLocation ?? _defaultLocation,
            markers: _markers.values.toSet(),
            onMapCreated: (controller) => _mapController = controller,
            onLongPress: _showAddPOIDialog,
          ),
          if (_isDebugVisible)
            DebugOverlay(
              logs: _debugLogs,
              onClear: _clearDebugLogs,
              isDarkTheme: Theme.of(context).brightness == Brightness.dark,
            ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _toggleDebugOverlay,
                icon: const Text('🐛', style: TextStyle(fontSize: 20)),
                tooltip: 'Toggle debug overlay',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
