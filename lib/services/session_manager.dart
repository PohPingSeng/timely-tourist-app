import 'package:cloud_firestore/cloud_firestore.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  String? _sessionTripId;
  String? get sessionTripId => _sessionTripId;

  Future<String> initializeSession(String userEmail) async {
    if (_sessionTripId != null) {
      return _sessionTripId!;
    }

    try {
      // Create a new trip document
      final tripRef = await FirebaseFirestore.instance.collection('trips').add({
        'userEmail': userEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'locations': [],
        'isCurrentTrip': true,
      });

      _sessionTripId = tripRef.id;

      // Update previous current trip status
      await FirebaseFirestore.instance
          .collection('trips')
          .where('userEmail', isEqualTo: userEmail)
          .where('isCurrentTrip', isEqualTo: true)
          .get()
          .then((querySnapshot) {
        for (var doc in querySnapshot.docs) {
          if (doc.id != _sessionTripId) {
            doc.reference.update({'isCurrentTrip': false});
          }
        }
      });

      return _sessionTripId!;
    } catch (e) {
      print('Error initializing session: $e');
      throw e;
    }
  }

  Future<void> clearSession() async {
    if (_sessionTripId != null) {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(_sessionTripId)
          .update({'isCurrentTrip': false});
      _sessionTripId = null;
    }
  }

  Future<void> setSessionTripId(String tripId) async {
    _sessionTripId = tripId;
  }
}
