import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splash_screen_1.dart';
import 'splash_screen_3.dart';

class PersonalInfoScreen extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic> userResponses;

  const PersonalInfoScreen({
    Key? key,
    required this.userEmail,
    required this.userResponses,
  }) : super(key: key);

  @override
  _PersonalInfoScreenState createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  String? selectedGender;
  bool isLoading = false;

  Future<void> _saveUserInfo() async {
    if (_formKey.currentState!.validate() && selectedGender != null) {
      setState(() {
        isLoading = true;
      });

      try {
        final userQuery = await FirebaseFirestore.instance
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .where('email', isEqualTo: widget.userEmail)
            .get();

        if (userQuery.docs.isNotEmpty) {
          String docId = userQuery.docs.first.id;
          await FirebaseFirestore.instance
              .collection('ttsUser')
              .doc('UID')
              .collection('UID')
              .doc(docId)
              .update({
            'name': nameController.text,
            'gender': selectedGender,
            'location': locationController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ResponseSummaryScreen(userEmail: widget.userEmail),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                transitionDuration: Duration(milliseconds: 300),
              ),
            );
          }
        }
      } catch (e) {
        print('Error saving user info: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save information. Please try again.')),
        );
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Title with divider
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Timely Tourist',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: Colors.grey[300],
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Welcome text
                Text(
                  'Wonderful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'You\'re about to start exploring, so\ntell about yourself!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 32),

                // Gender Selection
                Text(
                  'Select your Gender',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => selectedGender = 'Male'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedGender == 'Male'
                              ? Colors.black
                              : Colors.white,
                          foregroundColor: selectedGender == 'Male'
                              ? Colors.white
                              : Colors.black,
                          elevation: 0,
                          side: BorderSide(
                            color: selectedGender == 'Male'
                                ? Colors.black
                                : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (selectedGender == 'Male')
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.check, size: 18),
                              ),
                            Text('Male'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => selectedGender = 'Female'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedGender == 'Female'
                              ? Colors.black
                              : Colors.white,
                          foregroundColor: selectedGender == 'Female'
                              ? Colors.white
                              : Colors.black,
                          elevation: 0,
                          side: BorderSide(
                            color: selectedGender == 'Female'
                                ? Colors.black
                                : Colors.grey[300]!,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (selectedGender == 'Female')
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.check, size: 18),
                              ),
                            Text('Female'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Additional Information section
                Text(
                  'Addition information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Please enter your name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.red),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),

                Spacer(),

                // Next Button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InterestsSplashScreen(
                                userEmail: widget.userEmail,
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
                          '< Back',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveUserInfo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Next >',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    super.dispose();
  }
}
