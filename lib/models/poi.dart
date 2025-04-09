import 'package:geolocator/geolocator.dart';

class POI {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? story;
  final double triggerRadius;

  const POI({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.story,
    this.triggerRadius = 20.0,
  });

  factory POI.fromJson(Map<String, dynamic> json) {
    return POI(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      story: json['story'] as String?,
      triggerRadius: (json['triggerRadius'] as num?)?.toDouble() ?? 20.0,
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

  bool isWithinRange(double lat, double lng, double range) {
    return distanceTo(lat, lng) <= range;
  }

  POI copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? story,
    double? triggerRadius,
  }) {
    return POI(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      story: story ?? this.story,
      triggerRadius: triggerRadius ?? this.triggerRadius,
    );
  }

  @override
  String toString() => 'POI(id: $id, name: $name)';
} 