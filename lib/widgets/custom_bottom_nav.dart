import 'package:flutter/material.dart';
import '../explore.dart';
import '../map.dart';
import '../profile.dart';
import '../recommendation.dart';
import '../tripPlan.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final String userEmail;

  const CustomBottomNav({
    Key? key,
    required this.currentIndex,
    required this.userEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;

          Widget page;
          switch (index) {
            case 0:
              page = ExplorePage(userEmail: userEmail);
              break;
            case 1:
              page = RecommendationPage(userEmail: userEmail);
              break;
            case 2:
              page = MapPage(userEmail: userEmail);
              break;
            case 3:
              page = TripPlanPage(userEmail: userEmail);
              break;
            case 4:
              page = ProfilePage(userEmail: userEmail);
              break;
            default:
              return;
          }

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => page,
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: Duration(milliseconds: 300),
            ),
          );
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Color(0xFF0066FF),
        unselectedItemColor: Color(0xFF666666),
        items: [
          _buildNavItem(Icons.explore_outlined, Icons.explore, 'Explore',
              0 == currentIndex),
          _buildNavItem(Icons.lightbulb_outline, Icons.lightbulb, 'Recommended',
              1 == currentIndex),
          _buildAINavItem(currentIndex == 2),
          _buildNavItem(
              Icons.map_outlined, Icons.map, 'Trip Plan', 3 == currentIndex),
          _buildNavItem(
              Icons.person_outline, Icons.person, 'Profile', 4 == currentIndex),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
      IconData icon, IconData activeIcon, String label, bool isSelected) {
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF0066FF).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF0066FF).withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          size: 28,
          color: isSelected ? Color(0xFF0066FF) : Color(0xFF666666),
        ),
      ),
      label: label,
    );
  }

  BottomNavigationBarItem _buildAINavItem(bool isSelected) {
    return BottomNavigationBarItem(
      icon: Transform.translate(
        offset: Offset(0, isSelected ? -12 : -8),
        child: Container(
          height: 65,
          width: 65,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSelected
                  ? [Color(0xFF0066FF), Color(0xFF0052CC)]
                  : [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Color(0xFF0066FF).withOpacity(0.3)
                    : Colors.black12,
                blurRadius: 16,
                spreadRadius: 2,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.all(12),
            child: Image.asset(
              'assets/img/global_icon.png',
              color: isSelected ? Colors.white : Color(0xFF0066FF),
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      label: 'AI Map',
    );
  }
}
