import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/poi.dart';

/// Service for managing Points of Interest (POIs)
class POIService {
  static const String _poiFilePath = 'assets/pois/pois.json';
  List<POI> _pois = [];
  bool _isInitialized = false;

  /// Returns all POIs, loading them first if necessary
  Future<List<POI>> getPOIs() async {
    if (!_isInitialized) {
      await loadPOIs();
    }
    return _pois;
  }

  /// Loads POIs from the JSON file
  Future<void> loadPOIs() async {
    try {
      final String jsonString = await rootBundle.loadString(_poiFilePath);
      final List<dynamic> jsonList = json.decode(jsonString);
      _pois = jsonList.map((json) => POI.fromJson(json)).toList();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error loading POIs: $e');
      _pois = [];
    }
  }

  /// Adds a new POI and persists the changes
  Future<void> addPOI(POI poi) async {
    _pois.add(poi);
    await _savePOIs();
  }

  /// Removes a POI by ID and persists the changes
  Future<void> removePOI(String id) async {
    _pois.removeWhere((poi) => poi.id == id);
    await _savePOIs();
  }

  /// Updates an existing POI and persists the changes
  Future<void> updatePOI(POI updatedPoi) async {
    final index = _pois.indexWhere((poi) => poi.id == updatedPoi.id);
    if (index != -1) {
      _pois[index] = updatedPoi;
      await _savePOIs();
    }
  }

  /// Finds POIs within a specified range of a location
  List<POI> findPOIsInRange(double lat, double lng, double rangeMeters) {
    return _pois.where((poi) => 
      poi.isWithinRange(lat, lng, rangeMeters)
    ).toList();
  }

  /// Finds the closest POI to a given location
  POI? findClosestPOI(double lat, double lng) {
    if (_pois.isEmpty) return null;

    return _pois.reduce((closest, poi) {
      final closestDistance = closest.distanceTo(lat, lng);
      final poiDistance = poi.distanceTo(lat, lng);
      return poiDistance < closestDistance ? poi : closest;
    });
  }

  /// Saves POIs (currently in-memory only)
  Future<void> _savePOIs() async {
    // TODO: Implement persistent storage
    debugPrint('Saving POIs: ${_pois.length} items');
  }
} 