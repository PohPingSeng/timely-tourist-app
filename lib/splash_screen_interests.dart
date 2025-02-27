import 'package:flutter/material.dart';
import 'explore.dart';

class InterestsSplashScreen extends StatefulWidget {
  @override
  _InterestsSplashScreenState createState() => _InterestsSplashScreenState();
}

class _InterestsSplashScreenState extends State<InterestsSplashScreen> {
  final Set<String> selectedInterests = {};

  final List<String> interests = [
    'Adventure',
    'Beaches',
    'Camping',
    'Photography',
    'Heritage',
    'Mountains',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status bar
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    Text(
                      'Timely Tourist',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Title with heart icon
              Row(
                children: [
                  Text(
                    'Your interests',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.favorite_border, size: 24),
                ],
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                "Select things you're interested in and we'll\nrecommend places of interest to you.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 40),

              // Interests grid
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: interests.map((interest) {
                  final isSelected = selectedInterests.contains(interest);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedInterests.remove(interest);
                        } else {
                          selectedInterests.add(interest);
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        color: isSelected ? Colors.black : Colors.transparent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          Text(
                            interest,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              Spacer(),

              // Next button
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExplorePage(userEmail: 'user@example.com'),
                        ),
                      );
                    },
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
