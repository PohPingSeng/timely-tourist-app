import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';

class TripPlanPage extends StatelessWidget {
  final String userEmail;

  const TripPlanPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Trip Plan Page'),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 3,
        userEmail: userEmail,
      ),
    );
  }
}
