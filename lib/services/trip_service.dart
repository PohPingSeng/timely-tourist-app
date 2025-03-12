import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentTripId;

  // Initialize trip for a new session
  Future<void> initializeTrip(String userEmail) async {
    try {
      final newTripId = await createNewTrip(userEmail);
      _currentTripId = newTripId;
      print('New trip initialized with ID: $_currentTripId');
    } catch (e) {
      print('Error initializing trip: $e');
      throw Exception('Failed to initialize trip');
    }
  }

  // Create a new trip and return its ID
  Future<String> createNewTrip(String userEmail) async {
    // Create a new trip document with a unique ID
    final tripRef = await _firestore.collection('trips').add({
      'userEmail': userEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'isCurrentTrip': true,
      'locations': [],
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'summary': {
        'firstLocation': '',
        'lastLocation': '',
        'destinationCount': 0,
      },
    });

    final String newTripId = tripRef.id;

    // Set all other trips for this user as not current
    await _firestore
        .collection('trips')
        .where('userEmail', isEqualTo: userEmail)
        .where('isCurrentTrip', isEqualTo: true)
        .where(FieldPath.documentId, isNotEqualTo: newTripId)
        .get()
        .then((snapshots) {
      for (var doc in snapshots.docs) {
        doc.reference.update({'isCurrentTrip': false});
      }
    });

    return newTripId;
  }

  // Get current trip ID or create new one
  Future<String> getCurrentTripId(String userEmail) async {
    if (_currentTripId != null) {
      return _currentTripId!;
    }

    // Create new trip if none exists
    _currentTripId = await createNewTrip(userEmail);
    return _currentTripId!;
  }

  // Update locations in real-time
  Future<void> updateLocations(List<TripLocation> locations) async {
    if (_currentTripId == null) {
      throw Exception('No active trip ID');
    }

    final List<Map<String, dynamic>> locationData = locations
        .map((location) => {
              'placeId': location.placeId,
              'name': location.name,
              'address': location.address,
              'latitude': location.latLng.latitude,
              'longitude': location.latLng.longitude,
              'addedAt': FieldValue.serverTimestamp(),
            })
        .toList();

    // Create summary data
    Map<String, dynamic> summary = {
      'firstLocation': locations.isNotEmpty ? locations.first.name : '',
      'lastLocation': locations.isNotEmpty ? locations.last.name : '',
      'destinationCount': locations.length,
    };

    await _firestore.collection('trips').doc(_currentTripId).update({
      'locations': locationData,
      'updatedAt': FieldValue.serverTimestamp(),
      'summary': summary,
    });
  }

  // Delete location from trip
  Future<void> deleteLocation(String placeId) async {
    if (_currentTripId == null) {
      throw Exception('No active trip ID');
    }

    final tripDoc =
        await _firestore.collection('trips').doc(_currentTripId).get();
    if (!tripDoc.exists) return;

    List<dynamic> locations = tripDoc.data()?['locations'] ?? [];
    locations.removeWhere((loc) => loc['placeId'] == placeId);

    // Update summary after deletion
    Map<String, dynamic> summary = {
      'firstLocation': locations.isNotEmpty ? locations.first['name'] : '',
      'lastLocation': locations.isNotEmpty ? locations.last['name'] : '',
      'destinationCount': locations.length,
    };

    await _firestore.collection('trips').doc(_currentTripId).update({
      'locations': locations,
      'updatedAt': FieldValue.serverTimestamp(),
      'summary': summary,
    });
  }

  // Get all trips for a user
  Stream<QuerySnapshot> getUserTrips(String userEmail) {
    return _firestore
        .collection('trips')
        .where('userEmail', isEqualTo: userEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get specific trip details
  Stream<DocumentSnapshot> getTripDetails(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots();
  }

  // Delete a trip
  Future<void> deleteTrip(String tripId, String userEmail) async {
    // Verify the trip exists and belongs to the user
    final tripDoc = await _firestore.collection('trips').doc(tripId).get();
    if (!tripDoc.exists || tripDoc.data()?['userEmail'] != userEmail) {
      throw Exception('Trip not found or unauthorized');
    }

    // Delete the trip document
    await _firestore.collection('trips').doc(tripId).delete();

    if (tripId == _currentTripId) {
      _currentTripId = null;
    }
  }

  // Reset current trip (call on logout)
  void resetTripId() {
    _currentTripId = null;
  }

  // Convert Firestore data to TripLocation
  TripLocation convertToTripLocation(Map<String, dynamic> data) {
    return TripLocation(
      placeId: data['placeId'],
      name: data['name'],
      address: data['address'],
      latLng: LatLng(data['latitude'], data['longitude']),
    );
  }
}
