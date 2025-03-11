import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';
import 'recommendation.dart';
import 'profile.dart';
import 'popular_places.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/firestore_service.dart';

class ExplorePage extends StatefulWidget {
  final String userEmail;

  const ExplorePage({Key? key, required this.userEmail}) : super(key: key);

  @override
  _ExplorePageState createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _locationController = TextEditingController();
  Set<String> selectedCategories = {};
  List<String> categories = [
    'Mountains',
    'Beach',
    'City',
    'Historical Sites',
    'Adventure',
    'Nature and Outdoor',
    'Entertainment',
    'Cultural Spots',
    'Shopping Areas',
    'Events'
  ];
  List<Map<String, dynamic>> popularPlaces = [];
  final FirestoreService _firestoreService = FirestoreService();
  String userName = '';

  // Add this map for category icons
  final Map<String, IconData> categoryIcons = {
    'Mountains': Icons.landscape,
    'Beach': Icons.beach_access,
    'City': Icons.location_city,
    'Historical Sites': Icons.account_balance,
    'Adventure': Icons.hiking,
    'Nature and Outdoor': Icons.park,
    'Entertainment': Icons.movie,
    'Cultural Spots': Icons.museum,
    'Shopping Areas': Icons.shopping_bag,
    'Events': Icons.event,
  };

  @override
  void initState() {
    super.initState();
    _loadPopularPlaces();
    _loadUserName();
  }

  Future<void> _loadPopularPlaces() async {
    final String apiKey = 'AIzaSyD5fitoSIC-JDcKSTEOvnT0Yt-WF9NxvqQ';
    final List<Map<String, String>> places = [
      {'name': 'Mount Fuji', 'country': 'Japan'},
      {'name': 'Bali Beach', 'country': 'Indonesia'},
      {'name': 'Swiss Alps', 'country': 'Switzerland'},
      {'name': 'Grand Canyon', 'country': 'USA'},
      {'name': 'Eiffel Tower', 'country': 'France'},
    ];

    for (var place in places) {
      try {
        final response = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${place['name']}&key=$apiKey'));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['results'].isNotEmpty) {
            final result = data['results'][0];
            String photoUrl =
                'https://via.placeholder.com/180x120?text=${place['name']}';

            if (result['photos'] != null && result['photos'].isNotEmpty) {
              final photoReference = result['photos'][0]['photo_reference'];
              photoUrl =
                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoReference&key=$apiKey';
            }

            setState(() {
              popularPlaces.add({
                'name': place['name'] ?? '',
                'location': place['country'] ?? '',
                'rating': (result['rating']?.toString() ?? '4.0'),
                'image': photoUrl,
              });
            });
          }
        }
      } catch (e) {
        print('Error loading place: $e');
      }
    }
  }

  Future<void> _loadUserName() async {
    try {
      final userData = await _firestoreService.getUserData(widget.userEmail);
      setState(() {
        userName = userData?['name'] ?? 'User';
      });
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  void _applyFilters() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              RecommendationPage(userEmail: widget.userEmail)),
    );
  }

  void _clearFilters() {
    setState(() {
      _locationController.clear();
      selectedCategories.clear();
    });
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userEmail: widget.userEmail),
      ),
    );
  }

  void _navigateToAllPopularPlaces() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PopularPlacesPage(userEmail: widget.userEmail),
      ),
    );
  }

  void _showAllCategories(BuildContext context) {
    // Create a temporary set to hold selections
    Set<String> tempSelected = Set.from(selectedCategories);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Use StatefulBuilder to update dialog state
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'All Categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      height: 300,
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.1,
                        children: categories.map((category) {
                          bool isSelected = tempSelected.contains(category);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  tempSelected.remove(category);
                                } else {
                                  tempSelected.add(category);
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue[100]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue[800]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    categoryIcons[category] ?? Icons.category,
                                    size: 28,
                                    color: isSelected
                                        ? Colors.blue[800]
                                        : Colors.grey[600],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.blue[800]
                                          : Colors.grey[800],
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          this.setState(() {
                            selectedCategories = tempSelected;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: 0.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hi, $userName',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: _navigateToProfile,
                          child: Icon(Icons.account_circle_outlined, size: 35),
                        ),
                      ],
                    ),
                    Text(
                      'Explore destinations you want!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Search Bar
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filter By Destination',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 20, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Location',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Categories',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '(${selectedCategories.length} selected)',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => _showAllCategories(context),
                                child: Text(
                                  'See All',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Container(
                            height: 100,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  Container(
                                    width:
                                        MediaQuery.of(context).size.width * 1.5,
                                    child: GridView.count(
                                      crossAxisCount: 5,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 1.0,
                                      physics: NeverScrollableScrollPhysics(),
                                      children: categories.map((category) {
                                        bool isSelected = selectedCategories
                                            .contains(category);
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                selectedCategories
                                                    .remove(category);
                                              } else {
                                                selectedCategories
                                                    .add(category);
                                              }
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.blue[100]
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.blue[800]!
                                                    : Colors.grey[300]!,
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  categoryIcons[category] ??
                                                      Icons.category,
                                                  size: 28,
                                                  color: isSelected
                                                      ? Colors.blue[800]
                                                      : Colors.grey[600],
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  category,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isSelected
                                                        ? Colors.blue[800]
                                                        : Colors.grey[800],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _clearFilters,
                                child: Text('Clear'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[800],
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed:
                                    (_locationController.text.isNotEmpty ||
                                            selectedCategories.isNotEmpty)
                                        ? _applyFilters
                                        : null,
                                child: Text('Apply'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      (_locationController.text.isNotEmpty ||
                                              selectedCategories.isNotEmpty)
                                          ? Colors.blue[800]
                                          : Colors.blue[200],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),

                    // Popular Places section
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Popular Places',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              TextButton(
                                onPressed: _navigateToAllPopularPlaces,
                                child: Text(
                                  'See All',
                                  style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          Container(
                            height: 155,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: popularPlaces.length,
                              itemBuilder: (context, index) {
                                return _buildPopularCard(popularPlaces[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        userEmail: widget.userEmail,
      ),
    );
  }

  Widget _buildPopularCard(Map<String, dynamic> place) {
    return Container(
      width: 155,
      height: 155,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image container
          Container(
            height: 85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              image: DecorationImage(
                image: NetworkImage(
                    place['image'] ?? 'https://via.placeholder.com/180x120'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Details container
          Padding(
            padding: EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['name'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                    SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        place['location'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.star, size: 12, color: Colors.amber),
                    SizedBox(width: 2),
                    Text(
                      place['rating'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
