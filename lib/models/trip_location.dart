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

  Map<String, dynamic> toMap() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'latLng': {
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
      },
    };
  }

  static TripLocation fromMap(Map<String, dynamic> map) {
    return TripLocation(
      placeId: map['placeId'],
      name: map['name'],
      address: map['address'],
      latLng: LatLng(
        map['latLng']['latitude'],
        map['latLng']['longitude'],
      ),
    );
  }
}
