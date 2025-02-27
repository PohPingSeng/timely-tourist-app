import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';

class RecommendationPage extends StatelessWidget {
  final String userEmail;

  const RecommendationPage({Key? key, required this.userEmail})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Recommendations Page'),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1,
        userEmail: userEmail,
      ),
    );
  }
}
