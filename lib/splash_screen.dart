import 'package:flutter/material.dart';
import 'dart:ui' as ui show PathMetric;
import 'splash_screen_1.dart';
import 'explore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatelessWidget {
  final String userEmail;
  final String sessionTripId;

  const SplashScreen({
    Key? key,
    required this.userEmail,
    required this.sessionTripId,
  }) : super(key: key);

  void _handleGetStarted(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            InterestsSplashScreen(userEmail: userEmail),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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

  void _handleSkip(BuildContext context) async {
    try {
      // Check if user already has data in Firestore
      final userQuery = await FirebaseFirestore.instance
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      // Only navigate if we found existing data or confirmed skip
      if (userQuery.docs.isNotEmpty || await _confirmSkip(context)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExplorePage(userEmail: userEmail),
          ),
        );
      }
    } catch (e) {
      print('Error checking user data: $e');
    }
  }

  Future<bool> _confirmSkip(BuildContext context) async {
    if (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Skip Personalization?'),
            content: Text(
              'Your profile will show default values. You can always personalize later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Skip'),
              ),
            ],
          ),
        ) ??
        false) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App name at the top
            const Text(
              'Timely Tourist',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),

            // Circle with location icons
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Location markers and dotted line
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: DottedLinePainter(),
                  ),
                  Positioned(
                    top: 50,
                    left: 50,
                    child:
                        Icon(Icons.location_on, size: 30, color: Colors.black),
                  ),
                  Positioned(
                    bottom: 50,
                    right: 50,
                    child:
                        Icon(Icons.location_on, size: 30, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Text content
            const Text(
              'ALL YOUR TRAVEL\nPLANS IN ONE PLACE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Organize, track, and adjust your itinerary\nanytime, anywhere',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.2,
              ),
            ),
            const SizedBox(height: 40),

            // Get Started button
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _handleGetStarted(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
                SizedBox(height: 12),
                TextButton(
                  onPressed: () => _handleSkip(context),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for dotted line
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.5,
        size.width * 0.7,
        size.height * 0.7,
      );

    // Draw dotted line
    final Path dashPath = Path();
    final double dashWidth = 5.0;
    final double dashSpace = 5.0;
    double distance = 0.0;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth;
        distance += dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
