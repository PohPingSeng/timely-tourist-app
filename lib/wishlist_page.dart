import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tour_details_page.dart';

class WishlistPage extends StatefulWidget {
  final String userEmail;

  const WishlistPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> _getWishlistStream() {
    return _firestore
        .collection('ttsUser')
        .doc('UID')
        .collection('UID')
        .doc(widget.userEmail)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists) return [];

      List<dynamic> wishlist = snapshot.get('wishlist') ?? [];
      if (wishlist.isEmpty) return [];

      // Fetch all places in parallel
      final placeDocs = await Future.wait(
        wishlist.map(
            (placeId) => _firestore.collection('places').doc(placeId).get()),
      );

      return placeDocs
          .where((doc) => doc.exists)
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Wishlist'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getWishlistStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState();
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final places = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return _buildPlaceCard(place);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Your wishlist is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Save places you\'d like to visit later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Remove from Wishlist'),
              content: Text(
                  'Are you sure you want to remove this place from your wishlist?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Remove',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  image: DecorationImage(
                    image: NetworkImage(
                        place['image'] ?? 'https://via.placeholder.com/400'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place['name'] ?? 'Unknown location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (place['location'] != null) ...[
                      SizedBox(height: 4),
                      Text(
                        place['location'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      children: [
                        if (place['rating'] != null) ...[
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(place['rating'].toString()),
                        ],
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Implement add to trip
                          },
                          icon: Icon(Icons.add),
                          label: Text('Add to my trip'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TourDetailsPage(
                                  tourData: place,
                                  userEmail: widget.userEmail,
                                ),
                              ),
                            );
                          },
                          child: Text('More Details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: Colors.red[300],
                ),
                onPressed: () async {
                  if (await _showDeleteConfirmation(context)) {
                    await _removeFromWishlist(place['place_id']);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFromWishlist(String placeId) async {
    try {
      final userDocRef = _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .doc(widget.userEmail);

      final userDoc = await userDocRef.get();
      if (userDoc.exists) {
        List<String> wishlist =
            List<String>.from(userDoc.get('wishlist') ?? []);
        wishlist.remove(placeId);

        await userDocRef.set({
          'email': widget.userEmail,
          'wishlist': wishlist,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove from wishlist'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Simple skeleton loading widget
class Skeleton extends StatelessWidget {
  final double width;
  final double height;

  const Skeleton({
    Key? key,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
