import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class POI {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? story;
  final double triggerRadius;

  POI({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.story,
    this.triggerRadius = 20.0,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      story: json['story'],
      triggerRadius: json['triggerRadius'] ?? 20.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'story': story,
      'triggerRadius': triggerRadius,
    };
  }

  double distanceTo(double lat, double lng) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      lat,
      lng,
    );
  }
}

class POIService {
  static const String _poiFilePath = 'assets/pois/pois.json';
  List<POI> _pois = [];

  Future<void> loadPOIs() async {
    try {
      final String jsonString = await rootBundle.loadString(_poiFilePath);
      final List<dynamic> jsonList = json.decode(jsonString);
      _pois = jsonList.map((json) => POI.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading POIs: $e');
      _pois = [];
    }
  }

  List<POI> getPOIs() => _pois;

  Future<void> addPOI(POI poi) async {
    _pois.add(poi);
    await _savePOIs();
  }

  Future<void> removePOI(String id) async {
    _pois.removeWhere((poi) => poi.id == id);
    await _savePOIs();
  }

  Future<void> updatePOI(POI updatedPoi) async {
    final index = _pois.indexWhere((poi) => poi.id == updatedPoi.id);
    if (index != -1) {
      _pois[index] = updatedPoi;
      await _savePOIs();
    }
  }

  Future<void> _savePOIs() async {
    // Note: This is a placeholder. In a real app, you'd want to save to a file
    // or database. For now, we'll just keep it in memory.
    debugPrint('Saving POIs: ${_pois.length} items');
  }

  POI? findClosestPOI(double lat, double lng) {
    if (_pois.isEmpty) return null;

    POI closest = _pois.first;
    double minDistance = closest.distanceTo(lat, lng);

    for (var poi in _pois) {
      final distance = poi.distanceTo(lat, lng);
      if (distance < minDistance) {
        minDistance = distance;
        closest = poi;
      }
    }

    return closest;
  }
} 