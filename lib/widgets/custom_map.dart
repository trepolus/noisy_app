import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMap extends StatelessWidget {
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Function(GoogleMapController)? onMapCreated;

  const CustomMap({
    super.key,
    required this.initialPosition,
    required this.markers,
    this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 14.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: markers,
    );
  }
}
