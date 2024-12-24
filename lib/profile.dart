import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_bottom_nav.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _locationController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _locationController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userData =
          await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _usernameController.text = userData['username'] ?? '';
        _locationController.text = userData['location'] ?? '';
        _emailController.text = user.email ?? '';
        _passwordController.text = '********'; // For display only
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'username': _usernameController.text,
          'location': _locationController.text,
        });
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MyApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => MyApp()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 20,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[300],
                            child: Icon(Icons.person,
                                size: 50, color: Colors.grey[600]),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.edit,
                                    size: 15, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 10),
                      if (!_isEditing) ...[
                        Text(
                          _usernameController.text,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _locationController.text,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditing) ...[
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Username cannot be empty'
                                : null,
                          ),
                          SizedBox(height: 15),
                          TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                  });
                                },
                                child: Text('Cancel'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _updateProfile,
                                child: Text('Save'),
                              ),
                            ],
                          ),
                        ] else ...[
                          ListTile(
                            leading: Icon(Icons.person),
                            title: Text('Gender'),
                            subtitle: Text('Male'),
                          ),
                          ListTile(
                            leading: Icon(Icons.interests),
                            title: Text('Interests'),
                            subtitle: Text('Heritage, Photography'),
                          ),
                          ListTile(
                            leading: Icon(Icons.email),
                            title: Text('Email'),
                            subtitle: Text(_emailController.text),
                          ),
                          ListTile(
                            leading: Icon(Icons.lock),
                            title: Text('Password'),
                            subtitle: Text('********'),
                          ),
                          Divider(),
                          ListTile(
                            leading: Icon(Icons.favorite_border),
                            title: Text('Wishlist'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Navigate to wishlist
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.map),
                            title: Text('My Trips'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Navigate to trips
                            },
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                });
                              },
                              child: Text('Edit Profile'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(currentIndex: 4),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
