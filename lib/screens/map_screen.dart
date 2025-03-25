import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../widgets/custom_map.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  Map<MarkerId, Marker> _markers = {};

  final LatLng _defaultLocation = const LatLng(52.52, 13.405); // Berlin
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Set<MarkerId> _alreadyPlayed = {}; // markers already triggered

  static const double _triggerRadiusMeters = 20.0;


  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
    _startLiveLocation();
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

      // 🔊 Check proximity to each marker
      for (var entry in _markers.entries) {
        final markerId = entry.key;
        final marker = entry.value;

        if (_alreadyPlayed.contains(markerId)) continue;

        if (_isWithinRange(newLocation, marker.position, _triggerRadiusMeters)) {
          debugPrint('🔊 Playing sound for ${markerId.value}');
          await _audioPlayer.play(AssetSource('sounds/leiwand.m4a'));
          _showUnicornEmoji();
          _alreadyPlayed.add(markerId);
        }
      }
    });
  }


  void _handleMapTap(LatLng latLng) {
    final markerId = MarkerId('marker_${latLng.latitude}_${latLng.longitude}');

    final marker = Marker(
      markerId: markerId,
      position: latLng,
      infoWindow: InfoWindow(
        title: 'Pinned Location',
        snippet: '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}',
      ),
      onTap: () {
        setState(() {
          _markers.remove(markerId); // 👈 remove on tap
        });
      },
    );

    setState(() {
      _markers[markerId] = marker;
    });
  }

  bool _isWithinRange(LatLng pos1, LatLng pos2, double thresholdMeters) {
    final distance = Geolocator.distanceBetween(
      pos1.latitude,
      pos1.longitude,
      pos2.latitude,
      pos2.longitude,
    );
    return distance <= thresholdMeters;
  }

  void _showUnicornEmoji() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: MediaQuery.of(context).size.width / 2 - 24,
        child: const Text(
          '🦄',
          style: TextStyle(fontSize: 48),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }


  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
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
      appBar: AppBar(
        title: const Text('Leiwande Location'),
        backgroundColor: Colors.deepPurple, // 🎨 Purple!
      ),
        body: CustomMap(
          initialPosition: mapCenter,
          markers: _markers.values.toSet().union({
            if (_currentLocation != null)
              Marker(
                markerId: const MarkerId('user_location'),
                position: _currentLocation!,
                infoWindow: const InfoWindow(title: "You are here"),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
          }),
          onMapCreated: (controller) => _mapController = controller,
          onTap: _handleMapTap,
        ),
    );
  }
}
