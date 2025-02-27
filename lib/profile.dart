import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_bottom_nav.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;

  const ProfilePage({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showPassword = false;
  String _userPassword = '';
  String _userInterests = '';
  String _userGender = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final QuerySnapshot userDoc = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data() as Map<String, dynamic>;

        setState(() {
          _userPassword = userData['password'] ?? '';
          _userInterests = userData['interests']?.join(', ') ?? 'Not specified';
          _userGender = userData['gender'] ?? 'Not specified';
          _isLoading = false;
        });
      } else {
        print('No user document found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                    // Gender
                    ListTile(
                      leading: Icon(Icons.person_outline),
                      title: Text('Gender'),
                      subtitle: Text(_userGender),
                    ),

                    // Interests
                    ListTile(
                      leading: Icon(Icons.interests),
                      title: Text('Interests'),
                      subtitle: Text(_userInterests),
                    ),

                    // Email
                    ListTile(
                      leading: Icon(Icons.email_outlined),
                      title: Text('Email'),
                      subtitle: Text(widget.userEmail),
                    ),

                    // Password
                    ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('Password'),
                      subtitle: Text(_showPassword
                          ? _userPassword
                          : '•' * _userPassword.length),
                      trailing: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                    ),

                    Divider(),

                    // Wishlist
                    ListTile(
                      leading: Icon(Icons.favorite_border),
                      title: Text('Wishlist'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        // Navigate to wishlist
                      },
                    ),

                    // My Trips
                    ListTile(
                      leading: Icon(Icons.map_outlined),
                      title: Text('My Trips'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () {
                        // Navigate to trips
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
}
