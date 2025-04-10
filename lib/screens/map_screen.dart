import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/poi.dart';
import '../services/location_service.dart';
import '../services/poi_service.dart';
import '../theme/app_theme.dart';
import '../theme/map_style.dart';
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
    final BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueAzure
    );
    
    return Marker(
      markerId: MarkerId(poi.id),
      position: LatLng(poi.latitude, poi.longitude),
      icon: markerIcon,
      infoWindow: InfoWindow(
        title: poi.name,
        snippet: poi.story.length > 50 ? '${poi.story.substring(0, 50)}...' : poi.story,
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.dialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                poi.name,
                style: AppTheme.dialogTitle,
              ),
              const SizedBox(height: 16),
              Text(
                poi.story,
                style: AppTheme.dialogContent,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
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
                  style: AppTheme.closeButton,
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addNewPOI(LatLng position) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController storyController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.dialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Location',
                style: AppTheme.dialogTitle,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: AppTheme.inputDecoration('Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: storyController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: AppTheme.inputDecoration('Story'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: AppTheme.secondaryButton,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: AppTheme.primaryButton,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.errorDialogDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: AppTheme.dialogTitle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: AppTheme.dialogContent,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: AppTheme.errorButton,
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
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

  void _setMapStyle(GoogleMapController controller) {
    controller.setMapStyle(MapStyle.darkMap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Noisy',
          style: AppTheme.appBarTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.music_note, color: Colors.white),
            onPressed: _changeAmbientSound,
            tooltip: 'Change ambient sound',
          ),
          IconButton(
            icon: Icon(
              _isSoundEnabled ? Icons.volume_up : Icons.volume_off, 
              color: Colors.white
            ),
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
            onMapCreated: (controller) {
              _mapController = controller;
              _setMapStyle(controller);
            },
            onLongPress: _addNewPOI,
          ),
          if (_isDebugVisible)
            DebugOverlay(
              logs: _debugLogs,
              onClear: _clearDebugLogs,
              isDarkTheme: true,
            ),
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              decoration: AppTheme.floatingButtonDecoration,
              child: IconButton(
                onPressed: _toggleDebugOverlay,
                icon: const Icon(Icons.bug_report, color: Colors.white70),
                tooltip: 'Toggle debug overlay',
                style: IconButton.styleFrom(
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
