import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_bottom_nav.dart';
import 'main.dart';
import 'wishlist_page.dart';
import 'utils/page_transitions.dart';
import 'trip_plan_history.dart';
import 'services/session_manager.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;

  const ProfilePage({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SessionManager _sessionManager = SessionManager();
  Map<String, dynamic>? userData;
  StreamSubscription<QuerySnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _setupUserDataListener();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  void _setupUserDataListener() {
    try {
      _userDataSubscription = _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty && mounted) {
            setState(() {
              userData = snapshot.docs.first.data();
            });
          } else {
            setState(() {
              userData = null;
            });
          }
        },
        onError: (error) {
          print('Error listening to user data: $error');
        },
      );
    } catch (e) {
      print('Error setting up user data listener: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      // Clear the current trip session before logout
      await _sessionManager.clearSession();

      // Clear any stored trip data
      final querySnapshot = await _firestore
          .collection('trips')
          .where('userEmail', isEqualTo: widget.userEmail)
          .where('isCurrentTrip', isEqualTo: true)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.update({'isCurrentTrip': false});
      }

      // Sign out from Firebase Auth
      await _auth.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => TouristLoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // For centering the avatar
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    child:
                        Icon(Icons.person, size: 40, color: Colors.grey[400]),
                  ),
                  IconButton(
                    icon: Icon(Icons.logout),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),

            // Profile Information
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildProfileInformation(),

                    Divider(),

                    // Wishlist
                    ListTile(
                      leading: Icon(Icons.favorite_border),
                      title: Text('Wishlist'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          SlidePageRoute(
                            page: WishlistPage(userEmail: widget.userEmail),
                          ),
                        );
                      },
                    ),

                    // My Trips
                    ListTile(
                      leading: Icon(Icons.map_outlined),
                      title: Text('My Trips'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripPlanHistoryPage(
                              userEmail: widget.userEmail,
                            ),
                          ),
                        );
                      },
                    ),

                    const Spacer(),

                    // Edit Profile Button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextButton(
                        onPressed: () {
                          // Handle edit profile
                        },
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 4,
        userEmail: widget.userEmail,
      ),
    );
  }

  Widget _buildProfileInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        _buildInfoRow('Name', userData?['name'] ?? 'Not set'),
        _buildInfoRow('Email', widget.userEmail),
        _buildInfoRow('Gender', userData?['gender'] ?? 'Not set'),
        _buildInfoRow(
            'Personality Traits', userData?['personalityTraits'] ?? 'Not set'),
        _buildInfoRow(
            'Tourism Category', userData?['tourismCategory'] ?? 'Not set'),
        _buildInfoRow(
            'Travel Motivation',
            (['Extraversion', 'Conscientiousness', 'Agreeableness']
                    .contains(userData?['personalityTraits']))
                ? 'Not applicable'
                : (userData?['travelMotivation'] ?? 'Not set')),
        _buildInfoRow('Travelling Concerns',
            userData?['travellingConcerns'] ?? 'Not set'),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
