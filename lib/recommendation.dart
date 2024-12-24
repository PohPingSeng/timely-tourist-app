import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';

class RecommendationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Recommendations Page'),
      ),
      bottomNavigationBar: CustomBottomNav(currentIndex: 1),
    );
  }
}
