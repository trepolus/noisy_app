import 'package:geolocator/geolocator.dart';

class POI {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String story;

  POI({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.story,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      story: json['story'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'story': story,
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

  bool isWithinRange(double lat, double lng, double range) {
    return distanceTo(lat, lng) <= range;
  }

  POI copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? story,
  }) {
    return POI(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      story: story ?? this.story,
    );
  }

  @override
  String toString() => 'POI(id: $id, name: $name)';
} 