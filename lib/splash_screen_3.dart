import 'package:flutter/material.dart';
import 'services/firestore_service.dart';
import 'explore.dart';
import 'splash_screen_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResponseSummaryScreen extends StatefulWidget {
  final String userEmail;

  const ResponseSummaryScreen({
    Key? key,
    required this.userEmail,
  }) : super(key: key);

  @override
  _ResponseSummaryScreenState createState() => _ResponseSummaryScreenState();
}

class _ResponseSummaryScreenState extends State<ResponseSummaryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await _firestoreService.getUserData(widget.userEmail);
      setState(() {
        userData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateAndProceed() async {
    setState(() => isLoading = true);
    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;

        // Update all fields at once
        await FirebaseFirestore.instance
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(docId)
            .update({
          'personalityTraits': userData?['personalityTraits'] ?? '',
          'tourismCategory': userData?['tourismCategory'] ?? '',
          'travelMotivation': [
            'Extraversion',
            'Conscientiousness',
            'Agreeableness'
          ].contains(userData?['personalityTraits'])
              ? null
              : userData?['travelMotivation'],
          'travellingConcerns': userData?['travellingConcerns'] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Refresh data after update
        await _loadUserData();

        // Navigate to explore page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ExplorePage(userEmail: widget.userEmail),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save responses. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Center(
                  child: Text(
                    'Timely Tourist',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Progress bar
              LinearProgressIndicator(
                value: 1.0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),

              const SizedBox(height: 40),

              Text(
                'Your response',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // Icon and subtitle
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 48,
                      color: Colors.black,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'what we received from you',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // User information card
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Gender', userData?['gender'] ?? ''),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        'Personality', userData?['personalityTraits'] ?? ''),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        'Category', userData?['tourismCategory'] ?? ''),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        'Motivation', userData?['travelMotivation'] ?? ''),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        'Concerns', userData?['travellingConcerns'] ?? ''),
                  ],
                ),
              ),

              Spacer(),

              // Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonalInfoScreen(
                                userEmail: widget.userEmail,
                                userResponses: {},
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExplorePage(userEmail: widget.userEmail),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Finish',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
