import 'package:flutter/material.dart';
import 'dart:ui' as ui show PathMetric;
import 'explore.dart';
import 'splash_screen_interests.dart';

class SplashScreen extends StatelessWidget {
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

            // Buttons
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InterestsSplashScreen()),
                );
              },
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
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                   MaterialPageRoute(
                          builder: (context) => ExplorePage(userEmail: 'user@example.com'),
                        ),
                );
              },
              child: const Text(
                'Skip from now',
                style: TextStyle(color: Colors.grey),
              ),
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
