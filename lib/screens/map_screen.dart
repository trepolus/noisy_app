import 'dart:async';
import 'dart:math';

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
  final AudioPlayer _ambientPlayer = AudioPlayer();
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
  bool _isSoundEnabled = true;
  String _currentAmbientSound = '';

  // Constants
  static const double _minVolume = 0.0;
  static const double _maxVolume = 1.0;
  static const double _volumeTriggerRadius = 50.0;
  static const double _storyTriggerRadius = 10.0;
  static const double _defaultZoomLevel = 14.0;
  static const LatLng _defaultLocation = LatLng(52.52, 13.405); // Berlin
  static const Duration _volumeUpdateInterval = Duration(milliseconds: 100);
  static const List<String> _ambientSounds = [
    'sounds/ambient_rainy.mp3',
    'sounds/ambient_intro.mp3',
    'sounds/ambient_calm.mp3',
    'sounds/ambient_echoes.mp3',
    'sounds/ambient_ethereal.mp3',
  ];

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
    await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
    await _ambientPlayer.setVolume(0.0);
    // Don't play audio yet, we'll play it when a POI is close enough
  }

  String _getRandomAmbientSound() {
    final random = Random();
    return _ambientSounds[random.nextInt(_ambientSounds.length)];
  }

  Future<void> _playAmbientSound() async {
    if (!_isSoundEnabled) return;
    
    // Choose a random ambient sound if none is currently playing
    if (_currentAmbientSound.isEmpty) {
      _currentAmbientSound = _getRandomAmbientSound();
      _addDebugLog("Selected ambient sound: $_currentAmbientSound");
      await _ambientPlayer.play(AssetSource(_currentAmbientSound));
    }
  }

  Future<void> _changeAmbientSound() async {
    if (!_isSoundEnabled) return;
    
    // If we're already playing a sound, choose a different one
    String newSound;
    do {
      newSound = _getRandomAmbientSound();
    } while (newSound == _currentAmbientSound && _ambientSounds.length > 1);
    
    _addDebugLog("Changing ambient sound to: $newSound");
    
    // Save current volume
    final currentVolume = _currentVolume;
    
    // Stop current sound and play new one
    await _ambientPlayer.stop();
    _currentAmbientSound = newSound;
    await _ambientPlayer.play(AssetSource(_currentAmbientSound));
    await _ambientPlayer.setVolume(currentVolume);
  }

  Future<void> _stopAmbientSound() async {
    await _ambientPlayer.stop();
    _currentAmbientSound = '';
    _addDebugLog("Stopped ambient sound");
  }

  Future<void> _updateAmbientVolume(double distance) async {
    if (!_isSoundEnabled) return;

    double newVolume = 0.0;
    if (distance <= _volumeTriggerRadius) {
      // Start playing if we're in range and not already playing
      if (_currentAmbientSound.isEmpty) {
        await _playAmbientSound();
      }
      
      newVolume = 1.0 - (distance / _volumeTriggerRadius);
      newVolume = newVolume.clamp(_minVolume, _maxVolume);
    } else if (_currentAmbientSound.isNotEmpty) {
      // Stop playing if we're out of range
      await _stopAmbientSound();
    }

    if ((_currentVolume - newVolume).abs() > 0.01) {
      _currentVolume = newVolume;
      await _ambientPlayer.setVolume(_currentVolume);
      _addDebugLog("Updated ambient volume: ${_currentVolume.toStringAsFixed(2)}");
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

    final poisInRange = _poiService.findPOIsInRange(
      newLocation.latitude,
      newLocation.longitude,
      _volumeTriggerRadius,
    );

    if (poisInRange.isNotEmpty) {
      final closestPOI = poisInRange.reduce((a, b) {
        final distanceA = a.distanceTo(newLocation.latitude, newLocation.longitude);
        final distanceB = b.distanceTo(newLocation.latitude, newLocation.longitude);
        return distanceA < distanceB ? a : b;
      });

      final distance = closestPOI.distanceTo(
        newLocation.latitude,
        newLocation.longitude,
      );

      await _updateAmbientVolume(distance);
      _addDebugLog("Distance to closest POI (${closestPOI.name}): ${distance.toStringAsFixed(2)}m");

      if (distance <= _storyTriggerRadius && 
          !_triggeredPOIs.contains(closestPOI.id)) {
        _showStoryDialog(closestPOI);
        _triggeredPOIs.add(closestPOI.id);
        _addDebugLog("Triggered POI story: ${closestPOI.name}");
      }
    } else {
      await _updateAmbientVolume(_volumeTriggerRadius + 1); // Ensure we're out of range
      _addDebugLog("No POI in range");
    }
  }

  void _updateLocation(LatLng location) {
    setState(() => _currentLocation = location);
    _mapController?.animateCamera(CameraUpdate.newLatLng(location));
  }

  // UI Elements
  void _showStoryDialog(POI poi) {
    // Pause the ambient sound when showing the story
    _stopAmbientSound();
    _addDebugLog("Ambient sound paused for story dialog");
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(poi.name),
        content: Text(poi.story),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              
              // Resume ambient sound if in range
              final distance = poi.distanceTo(
                _currentLocation!.latitude,
                _currentLocation!.longitude,
              );
              if (distance <= _volumeTriggerRadius && _isSoundEnabled) {
                _updateAmbientVolume(distance);
                _addDebugLog("Ambient sound resumed after story dialog");
              }
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewPOI(LatLng position) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController storyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New POI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: storyController,
              decoration: const InputDecoration(labelText: 'Story'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty && storyController.text.isNotEmpty) {
      final newPOI = POI(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text,
        latitude: position.latitude,
        longitude: position.longitude,
        story: storyController.text,
      );

      await _poiService.addPOI(newPOI);
      _addDebugLog("Added new POI: ${newPOI.name}");
      await _loadPOIs();
    }
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

  Future<void> _toggleSound() async {
    setState(() {
      _isSoundEnabled = !_isSoundEnabled;
    });
    if (_isSoundEnabled) {
      if (_currentVolume > 0) {
        await _playAmbientSound();
        await _ambientPlayer.setVolume(_currentVolume);
      }
    } else {
      await _stopAmbientSound();
    }
    _addDebugLog("Sound ${_isSoundEnabled ? 'enabled' : 'disabled'}");
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _ambientPlayer.dispose();
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
            icon: const Icon(Icons.refresh),
            onPressed: _changeAmbientSound,
            tooltip: 'Change ambient sound',
          ),
          IconButton(
            icon: Icon(_isSoundEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: _toggleSound,
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
            onLongPress: _addNewPOI,
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
