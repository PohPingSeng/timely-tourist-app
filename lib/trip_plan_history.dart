import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tripPlan.dart';
import 'models/trip_location.dart';
import 'services/trip_service.dart';
import 'services/session_manager.dart';

class TripPlanHistoryPage extends StatefulWidget {
  final String userEmail;

  const TripPlanHistoryPage({Key? key, required this.userEmail})
      : super(key: key);

  @override
  _TripPlanHistoryPageState createState() => _TripPlanHistoryPageState();
}

class _TripPlanHistoryPageState extends State<TripPlanHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TripService _tripService = TripService();
  final SessionManager _sessionManager = SessionManager();

  Future<void> _createNewTrip() async {
    try {
      // Create a new trip document
      final tripRef = await _firestore.collection('trips').add({
        'userEmail': widget.userEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'locations': [],
        'isCurrentTrip': true,
      });

      // Update session manager with new trip ID
      await _sessionManager.setSessionTripId(tripRef.id);

      // Update previous current trip status
      await _firestore
          .collection('trips')
          .where('userEmail', isEqualTo: widget.userEmail)
          .where('isCurrentTrip', isEqualTo: true)
          .get()
          .then((querySnapshot) {
        for (var doc in querySnapshot.docs) {
          if (doc.id != tripRef.id) {
            doc.reference.update({'isCurrentTrip': false});
          }
        }
      });

      // Navigate to TripPlan with the new trip ID
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TripPlanPage(
            userEmail: widget.userEmail,
            tripId: tripRef.id,
          ),
        ),
      );
    } catch (e) {
      print('Error creating new trip: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create new trip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.luggage_outlined),
            SizedBox(width: 8),
            Text('My Trips'),
          ],
        ),
        leading: IconButton(
          icon: Text('back'),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('trips')
                .where('userEmail', isEqualTo: widget.userEmail)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading trips: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }

              final trips = snapshot.data?.docs ?? [];

              if (trips.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.luggage_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No trips yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final data = trip.data() as Map<String, dynamic>;
                  final locations =
                      List<Map<String, dynamic>>.from(data['locations'] ?? []);
                  final isCurrentTrip = data['isCurrentTrip'] ?? false;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isCurrentTrip
                            ? Colors.blue[300]!
                            : Colors.grey[300]!,
                        width: isCurrentTrip ? 2.0 : 1.0,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripPlanPage(
                              userEmail: widget.userEmail,
                              savedLocations: locations
                                  .map((loc) => TripLocation.fromMap(loc))
                                  .toList(),
                              tripId: trip.id,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.luggage_outlined,
                              color: isCurrentTrip ? Colors.blue : null,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLocationsList(locations),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${locations.length} destination${locations.length != 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (isCurrentTrip) ...[
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'CURRENT TRIP',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isCurrentTrip)
                              IconButton(
                                icon: Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _confirmDelete(context, trip.id),
                                color: Colors.grey[400],
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(minWidth: 40),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          _buildNewTripButton(),
        ],
      ),
    );
  }

  Widget _buildLocationsList(List<Map<String, dynamic>> locations) {
    if (locations.isEmpty) {
      return Text(
        'No locations added',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: locations.asMap().entries.map((entry) {
        final isLast = entry.key == locations.length - 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                entry.value['name'] ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isLast)
              Text(
                ' → ',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildNewTripButton() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _createNewTrip,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('New Trip'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String tripId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Delete Trip'),
        content: Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                print('Attempting to delete trip: $tripId'); // Debug print
                await _firestore.collection('trips').doc(tripId).delete();
              } catch (e) {
                print('Delete error: $e'); // Debug print
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete trip: $e')),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
