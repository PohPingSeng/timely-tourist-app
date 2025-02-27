import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user document reference
  Future<DocumentReference?> getUserDocRef(String email) async {
    final userQuery = await _firestore
        .collection('ttsUser')
        .doc('UID')
        .collection('UID')
        .where('email', isEqualTo: email)
        .get();

    if (userQuery.docs.isNotEmpty) {
      return userQuery.docs.first.reference;
    }
    return null;
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String email) async {
    final docRef = await getUserDocRef(email);
    if (docRef != null) {
      final doc = await docRef.get();
      // Cast the data to Map<String, dynamic>
      return doc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  // Update user data
  Future<void> updateUserData(String email, Map<String, dynamic> data) async {
    final docRef = await getUserDocRef(email);
    if (docRef != null) {
      await docRef.update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
