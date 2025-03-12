import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip_location.dart';

class TripPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentTripId;

  // Get current trip ID or create new one
  Future<String> getCurrentTripId(String userEmail) async {
    if (_currentTripId != null) return _currentTripId!;

    try {
      // Check for existing active trip
      final currentTrips = await _firestore
          .collection('trips')
          .where('userEmail', isEqualTo: userEmail)
          .where('isCurrentTrip', isEqualTo: true)
          .limit(1)
          .get();

      if (currentTrips.docs.isNotEmpty) {
        _currentTripId = currentTrips.docs.first.id;
        return _currentTripId!;
      }

      // Create new trip if none exists
      final tripData = {
        'userEmail': userEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'locations': [],
        'isCurrentTrip': true,
      };

      final docRef = await _firestore.collection('trips').add(tripData);
      _currentTripId = docRef.id;
      return _currentTripId!;
    } catch (e) {
      throw Exception('Failed to get/create trip: $e');
    }
  }

  // Update locations in real-time
  Future<void> updateLocations(List<TripLocation> locations) async {
    if (_currentTripId == null) throw Exception('No active trip');

    final locationData = locations
        .map((loc) => {
              'name': loc.name,
              'address': loc.address,
              'placeId': loc.placeId,
              'latitude': loc.latLng.latitude,
              'longitude': loc.latLng.longitude,
            })
        .toList();

    await _firestore.collection('trips').doc(_currentTripId).update({
      'locations': locationData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // End current trip on logout
  Future<void> endCurrentTrip() async {
    if (_currentTripId == null) return;

    await _firestore.collection('trips').doc(_currentTripId).update({
      'isCurrentTrip': false,
    });
    _currentTripId = null;
  }

  // Get trip history stream
  Stream<QuerySnapshot> getTripHistory(String userEmail) {
    return _firestore
        .collection('trips')
        .where('userEmail', isEqualTo: userEmail)
        .orderBy('isCurrentTrip', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }
}
