import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripLocation {
  final String placeId;
  final String name;
  final String address;
  final LatLng latLng;

  TripLocation({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latLng,
  });
} 