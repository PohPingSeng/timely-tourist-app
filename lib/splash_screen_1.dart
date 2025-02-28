import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splash_screen_2.dart';

class InterestsSplashScreen extends StatefulWidget {
  final String userEmail;

  const InterestsSplashScreen({Key? key, required this.userEmail})
      : super(key: key);

  @override
  _InterestsSplashScreenState createState() => _InterestsSplashScreenState();
}

class _InterestsSplashScreenState extends State<InterestsSplashScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedPersonality;
  String? selectedCategory;
  String? selectedMotivation;
  String? selectedConcern;
  int currentQuestionIndex = 0;
  bool isLoading = false;

  // Store user responses
  Map<String, dynamic> userResponses = {};

  // Add at the top of the class with other variables
  final Map<String, List<Map<String, String>>> categoryQuestions = {
    'Extraversion': [
      {
        'text':
            'Sign up for an extreme adventure like bungee jumping or white-water rafting.',
        'value': 'Adrenaline Activities'
      },
      {
        'text':
            'Join a group hiking tour to explore hidden trails and waterfalls.',
        'value': 'Wild Nature Activities'
      },
      {
        'text':
            'Find out where the best nightlife spots, concerts, or festivals are happening.',
        'value': 'Party, Music & Nightlife'
      },
      {
        'text': 'Head to a beach with water sports and lively crowds.',
        'value': 'Sun & Water'
      },
      {
        'text':
            'Visit an interactive animal park or a theme park filled with fun rides.',
        'value': 'Theme & Animal Parks'
      },
      {
        'text':
            'Challenge locals to a friendly game of soccer, volleyball, or another sport.',
        'value': 'Sports & Games'
      },
      {
        'text': 'Try a famous street food festival or cooking workshop.',
        'value': 'Gastronomy Events'
      },
      {
        'text': 'Book a spa session to recover from your journey.',
        'value': 'Health & Well-being'
      },
      {
        'text':
            'Set out to capture breathtaking landscapes on a photography tour.',
        'value': 'Natural Phenomena'
      },
    ],
    'Conscientiousness': [
      {
        'text': 'Find a safe and well-planned outdoor adventure to replace it.',
        'value': 'Adrenaline Activities'
      },
      {
        'text': 'Join a guided wildlife tour or photography session instead.',
        'value': 'Wild Nature Activities'
      },
      {
        'text': 'Visit a local museum or viewpoint for a cultural experience.',
        'value': 'Museums & Viewpoints'
      },
      {
        'text': 'Book an alternative sports event or competition.',
        'value': 'Sports & Games'
      },
      {
        'text': 'Take a guided nature excursion to see spectacular landscapes.',
        'value': 'Natural Phenomena'
      },
      {
        'text':
            'Explore a popular nightlife district or find a live music event.',
        'value': 'Party, Music & Nightlife'
      },
    ],
    'Agreeableness': [
      {
        'text': 'A cultural heritage site with a knowledgeable guide.',
        'value': 'Cultural Heritage'
      },
      {
        'text':
            'A wellness retreat for relaxation, meditation, or hot springs.',
        'value': 'Health & Well-being'
      },
      {
        'text': 'A theme park or zoo for a lighthearted and fun experience.',
        'value': 'Theme & Animal Parks'
      },
      {
        'text':
            'A historic museum to explore artifacts and stories from the past.',
        'value': 'Museums'
      },
      {
        'text':
            'A popular dining or entertainment spot with a social atmosphere.',
        'value': 'Party, Music & Nightlife'
      },
      {
        'text':
            'A restaurant famous for its traditional dishes and local delicacies.',
        'value': 'Gastronomy Events'
      },
      {
        'text': 'A park where you can enjoy gentle outdoor activities.',
        'value': 'Sports & Games'
      },
      {
        'text': 'A quiet, picturesque location to admire nature.',
        'value': 'Natural Phenomena'
      },
      {
        'text': 'A scenic hiking trail that isn\'t too challenging.',
        'value': 'Wild Nature Activities'
      },
    ],
    'Neuroticism': [
      {
        'text': 'Check out popular entertainment spots, concerts, or events.',
        'value': 'Party, Music & Nightlife'
      },
      {
        'text': 'Visit an amusement park or interactive animal sanctuary.',
        'value': 'Theme & Animal Parks'
      },
      {
        'text': 'Book a wellness retreat or spa treatment to unwind.',
        'value': 'Health & Well-being'
      },
    ],
    'Openness': [
      {
        'text': 'Wander through local food markets and try traditional dishes.',
        'value': 'Gastronomy Events'
      },
      {
        'text':
            'Go on an island adventure with a mix of relaxation and activities.',
        'value': 'Sun, Water & Sand'
      },
      {
        'text': 'Seek out a vibrant festival or a lively cultural event.',
        'value': 'Party, Music & Nightlife'
      },
      {
        'text': 'Visit a theme park with immersive, interactive attractions.',
        'value': 'Theme & Animal Parks'
      },
      {
        'text':
            'Sign up for an extreme sport or an adrenaline-filled activity.',
        'value': 'Sports & Games'
      },
      {
        'text': 'Spend the day at a wellness retreat or self-care experience.',
        'value': 'Health & Well-being'
      },
    ],
  };

  final Map<String, List<Map<String, String>>> motivationQuestions = {
    'Neuroticism': [
      {
        'text':
            'I want to push myself outside my comfort zone and grow as a person.',
        'value': 'Self-Development & Reliance'
      },
      {
        'text': 'I want to meet new people and feel a sense of connection.',
        'value': 'Connectedness & Recognition'
      },
      {
        'text':
            'I want a mix of fun and excitement, but I need to feel safe too.',
        'value': 'Novelty & Excitement'
      },
    ],
    'Openness': [
      {
        'text': 'I love learning new skills and gaining fresh perspectives.',
        'value': 'Self-Development & Reliance'
      },
      {
        'text':
            'Meeting people and experiencing new cultures makes travel special.',
        'value': 'Connectedness & Recognition'
      },
      {
        'text': 'I seek new and thrilling experiences wherever I go.',
        'value': 'Novelty & Excitement'
      },
      {
        'text': 'Relaxing and bonding with friends or family is my priority.',
        'value': 'Bond & Relax'
      },
      {
        'text': 'I enjoy discovering the beauty of nature.',
        'value': 'Nature Enjoyment'
      },
    ],
  };

  final Map<String, List<Map<String, String>>> concernQuestions = {
    'Extraversion': [
      {
        'text':
            'I love discovering new and unusual things that make a trip unforgettable!',
        'value': 'Uniqueness & Exoticness'
      },
    ],
    'Conscientiousness': [
      {
        'text':
            'I want to dive into history and learn about different cultures.',
        'value': 'Cultural & Learning Experiences'
      },
      {
        'text': 'I prefer destinations that feel comfortable and familiar.',
        'value': 'Familiarity'
      },
    ],
    'Agreeableness': [
      {
        'text': 'I want to feel safe and know what to expect at all times.',
        'value': 'Previsibility & Safety'
      },
      {
        'text':
            'I enjoy new experiences, but I prefer them to feel comfortable.',
        'value': 'Uniqueness & Exoticness'
      },
      {
        'text': 'I\'d rather stick to places I already know and love.',
        'value': 'Familiarity'
      },
    ],
    'Neuroticism': [
      {
        'text': 'I feel uneasy but try to adapt and make the best of it.',
        'value': 'Cultural & Learning Experiences'
      },
      {
        'text':
            'I look for an alternative plan that feels comfortable and familiar.',
        'value': 'Familiarity'
      },
    ],
    'Openness': [
      {
        'text': 'I want to feel safe and confident in my surroundings.',
        'value': 'Previsibility & Safety'
      },
      {
        'text':
            'I want to learn something new and immerse myself in the culture.',
        'value': 'Cultural & Learning Experiences'
      },
      {
        'text': 'I seek experiences that are rare and unforgettable.',
        'value': 'Uniqueness & Exoticness'
      },
    ],
  };

  // Update canProceed to handle question counts correctly
  bool get canProceed {
    switch (currentQuestionIndex) {
      case 0:
        return selectedPersonality != null;
      case 1:
        return selectedCategory != null;
      case 2:
        if (selectedPersonality == 'Extraversion') {
          return true; // Always proceed since Q3 is automatic
        } else if (selectedPersonality == 'Neuroticism' ||
            selectedPersonality == 'Openness') {
          return selectedMotivation != null;
        }
        return selectedConcern != null;
      case 3:
        return selectedConcern != null;
      default:
        return false;
    }
  }

  Future<void> _storeResponse(String field, String value) async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get reference to user document
      final userQuery = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;

        // Update the specific field
        await _firestore
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(docId)
            .update({
          field: value,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Store in local state
        setState(() {
          userResponses[field] = value;
        });
      }
    } catch (e) {
      print('Error storing response: $e');
      // You might want to show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save response. Please try again.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handlePersonalitySelection(String personality) async {
    setState(() => isLoading = true);
    try {
      final userQuery = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;
        print(
            'Saving personality data for user: ${widget.userEmail}, docId: $docId'); // Debug log

        await _firestore
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(docId)
            .update({
          'personalityTraits': personality,
          'tourismCategory': null,
          'travelMotivation': null,
          'travellingConcerns': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('Successfully saved personality: $personality'); // Debug log
      }
      setState(() {
        selectedPersonality = personality;
        currentQuestionIndex++;
        isLoading = false;
      });
    } catch (e) {
      print('Error updating: $e');
      setState(() => isLoading = false);
    }
  }

  void _handleCategorySelection(String category) async {
    setState(() => isLoading = true);
    try {
      final userQuery = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;
        await _firestore
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(docId)
            .update({
          'tourismCategory': category,
          'travellingConcerns': selectedPersonality == 'Extraversion'
              ? 'Uniqueness & Exoticness'
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      setState(() {
        selectedCategory = category;
        if (selectedPersonality == 'Extraversion') {
          selectedConcern = 'Uniqueness & Exoticness';
          _proceedToNextScreen(); // Skip to next screen
        } else if (selectedPersonality == 'Neuroticism' ||
            selectedPersonality == 'Openness') {
          currentQuestionIndex++;
        } else {
          currentQuestionIndex = 2;
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error updating: $e');
      setState(() => isLoading = false);
    }
  }

  void _handleMotivationSelection(String motivation) async {
    // Only allow motivation for Neuroticism and Openness
    if (selectedPersonality != 'Neuroticism' &&
        selectedPersonality != 'Openness') {
      return;
    }

    setState(() => isLoading = true);
    try {
      final userQuery = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;
        await _firestore
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(docId)
            .update({
          'travelMotivation': motivation,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      setState(() {
        selectedMotivation = motivation;
        currentQuestionIndex++;
        isLoading = false;
      });
    } catch (e) {
      print('Error updating: $e');
      setState(() => isLoading = false);
    }
  }

  void _handleConcernSelection(String concern) async {
    setState(() => isLoading = true);
    try {
      final userQuery = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String docId = userQuery.docs.first.id;
        await _firestore
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(docId)
            .update({
          'travellingConcerns': concern,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      setState(() {
        selectedConcern = concern;
        isLoading = false;
        _proceedToNextScreen();
      });
    } catch (e) {
      print('Error updating: $e');
      setState(() => isLoading = false);
    }
  }

  void _proceedToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInfoScreen(
          userEmail: widget.userEmail,
          userResponses: userResponses, // Pass the responses
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    switch (currentQuestionIndex) {
      case 0:
        return _buildPersonalityQuestion();
      case 1:
        return _buildCategoryQuestion();
      case 2:
        return _buildMotivationQuestion();
      case 3:
        return _buildConcernQuestion();
      default:
        return Container();
    }
  }

  // Build your question widgets here...
  // Example for personality question:
  Widget _buildPersonalityQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When planning a trip, what best describes your approach?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),
        _buildOptionsList([
          {
            'text':
                'I love the thrill of last-minute decisions and meeting new people along the way!',
            'value': 'Extraversion'
          },
          {
            'text':
                'I feel most comfortable when I have a detailed itinerary and everything is well-organized.',
            'value': 'Conscientiousness'
          },
          {
            'text':
                'I prefer familiar places where I can relax without worrying about too many surprises.',
            'value': 'Agreeableness'
          },
          {
            'text':
                'I enjoy new experiences but like to have a backup plan in case things don\'t go as expected.',
            'value': 'Neuroticism'
          },
          {
            'text':
                'I seek unique cultural experiences and love immersing myself in different ways of life!',
            'value': 'Openness'
          },
        ], _handlePersonalitySelection),
      ],
    );
  }

  Widget _buildOptionsList(
      List<Map<String, String>> options, Function(String) onSelect) {
    return Column(
      children: options.map((option) {
        bool isSelected = false;

        // Check if this option is selected based on the current question
        switch (currentQuestionIndex) {
          case 0:
            isSelected = selectedPersonality == option['value'];
            break;
          case 1:
            isSelected = selectedCategory == option['value'];
            break;
          case 2:
            isSelected = selectedMotivation == option['value'];
            break;
          case 3:
            isSelected = selectedConcern == option['value'];
            break;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () => onSelect(option['value']!),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.black : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color:
                    isSelected ? Colors.black.withOpacity(0.05) : Colors.white,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option['text']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight:
                            isSelected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Colors.black,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedPersonality == 'Extraversion'
              ? 'You arrive at your destination with a free day ahead. What do you do first?'
              : selectedPersonality == 'Conscientiousness'
                  ? 'You have planned a detailed trip, but one activity gets canceled. How do you react?'
                  : selectedPersonality == 'Agreeableness'
                      ? 'You\'ve just arrived at a new place. Where do you go first?'
                      : selectedPersonality == 'Neuroticism'
                          ? 'You find yourself in an unfamiliar city. How do you spend your day?'
                          : 'Your trip includes a free day to explore however you like. What do you choose?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),
        _buildOptionsList(
          categoryQuestions[selectedPersonality] ?? [],
          _handleCategorySelection,
        ),
      ],
    );
  }

  Widget _buildMotivationQuestion() {
    // For Neuroticism and Openness, show motivation question
    if (selectedPersonality == 'Neuroticism' ||
        selectedPersonality == 'Openness') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you hope to gain from this trip?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          _buildOptionsList(
            motivationQuestions[selectedPersonality] ?? [],
            _handleMotivationSelection,
          ),
        ],
      );
    }

    // For others, skip to concern question
    setState(() {
      currentQuestionIndex = 2;
    });
    return Container();
  }

  Widget _buildConcernQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedPersonality == 'Extraversion'
              ? 'A friend asks why you love traveling. What\'s your response?'
              : selectedPersonality == 'Conscientiousness'
                  ? 'When choosing a travel destination, what is your top priority?'
                  : selectedPersonality == 'Agreeableness'
                      ? 'If something unexpected happens during your trip, what concerns you the most?'
                      : selectedPersonality == 'Neuroticism'
                          ? 'Something unexpected forces you to change your itinerary. What do you do?'
                          : 'When choosing a destination, what is most important to you?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 32),
        _buildOptionsList(
          concernQuestions[selectedPersonality] ?? [],
          _handleConcernSelection,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header Section
            Container(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Title
                  Text(
                    'Timely Tourist',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Subtitle
                  Text(
                    'Your interests',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Question number with heart icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${currentQuestionIndex + 1}. Question',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Question Title (Fixed)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: _buildQuestionTitle(),
            ),

            // Scrollable Answer Options
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
                child: SingleChildScrollView(
                  physics: ClampingScrollPhysics(),
                  child: _buildAnswerOptions(),
                ),
              ),
            ),

            // Fixed Bottom Button
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  // Back Button
                  if (currentQuestionIndex > 0)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    currentQuestionIndex--;
                                  });
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
                    ),
                  // Next Button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (isLoading || !canProceed)
                          ? null
                          : () {
                              if (currentQuestionIndex < 3) {
                                setState(() {
                                  currentQuestionIndex++;
                                });
                              } else {
                                _proceedToNextScreen();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Grey out button when disabled
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Next >',
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
    );
  }

  // Update _buildQuestionTitle to show correct questions
  Widget _buildQuestionTitle() {
    if (isLoading) return Container();

    switch (currentQuestionIndex) {
      case 0:
        return Text(
          'When planning a trip, what best describes your approach?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        );
      case 1:
        return Text(
          selectedPersonality == 'Extraversion'
              ? 'You arrive at your destination with a free day ahead. What do you do first?'
              : selectedPersonality == 'Conscientiousness'
                  ? 'You have planned a detailed trip, but one activity gets canceled. How do you react?'
                  : selectedPersonality == 'Agreeableness'
                      ? 'You\'ve just arrived at a new place. Where do you go first?'
                      : selectedPersonality == 'Neuroticism'
                          ? 'You find yourself in an unfamiliar city. How do you spend your day?'
                          : 'Your trip includes a free day to explore however you like. What do you choose?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        );
      case 2:
        // Show different motivation questions for Neuroticism and Openness
        if (selectedPersonality == 'Neuroticism') {
          return Text(
            'What do you hope to gain from this trip?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          );
        } else if (selectedPersonality == 'Openness') {
          return Text(
            'What excites you the most about travel?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          );
        }
        // For others, show their respective Q3
        return Text(
          selectedPersonality == 'Conscientiousness'
              ? 'When choosing a travel destination, what is your top priority?'
              : selectedPersonality == 'Agreeableness'
                  ? 'If something unexpected happens during your trip, what concerns you the most?'
                  : '', // Extraversion doesn't reach here
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        );
      case 3:
        // Only Neuroticism and Openness reach this case
        return Text(
          selectedPersonality == 'Neuroticism'
              ? 'Something unexpected forces you to change your itinerary. What do you do?'
              : 'When choosing a destination, what is most important to you?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        );
      default:
        return Container();
    }
  }

  // Update _buildAnswerOptions to handle different flows
  Widget _buildAnswerOptions() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    switch (currentQuestionIndex) {
      case 0:
        return _buildOptionsList([
          {
            'text':
                'I love the thrill of last-minute decisions and meeting new people along the way!',
            'value': 'Extraversion'
          },
          {
            'text':
                'I feel most comfortable when I have a detailed itinerary and everything is well-organized.',
            'value': 'Conscientiousness'
          },
          {
            'text':
                'I prefer familiar places where I can relax without worrying about too many surprises.',
            'value': 'Agreeableness'
          },
          {
            'text':
                'I enjoy new experiences but like to have a backup plan in case things don\'t go as expected.',
            'value': 'Neuroticism'
          },
          {
            'text':
                'I seek unique cultural experiences and love immersing myself in different ways of life!',
            'value': 'Openness'
          },
        ], _handlePersonalitySelection);
      case 1:
        return _buildOptionsList(categoryQuestions[selectedPersonality] ?? [],
            _handleCategorySelection);
      case 2:
        // For Neuroticism and Openness, show motivation questions
        if (selectedPersonality == 'Neuroticism' ||
            selectedPersonality == 'Openness') {
          return _buildOptionsList(
              motivationQuestions[selectedPersonality] ?? [],
              _handleMotivationSelection);
        }
        // For others, show concern questions
        return _buildOptionsList(concernQuestions[selectedPersonality] ?? [],
            _handleConcernSelection);
      case 3:
        // Only Neuroticism and Openness reach this case
        return _buildOptionsList(concernQuestions[selectedPersonality] ?? [],
            _handleConcernSelection);
      default:
        return Container();
    }
  }
}
