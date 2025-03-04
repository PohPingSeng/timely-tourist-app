import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';
import 'services/recommendation_service.dart';
import 'tour_details_page.dart';

class RecommendationPage extends StatefulWidget {
  final String userEmail;

  const RecommendationPage({Key? key, required this.userEmail})
      : super(key: key);

  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final RecommendationService _recommendationService = RecommendationService();
  List<Map<String, dynamic>> recommendations = [];
  List<Map<String, dynamic>> filteredRecommendations = [];
  String selectedFilter = 'Any time';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final recs =
          await _recommendationService.getRecommendations(widget.userEmail);
      setState(() {
        recommendations = recs;
        _applyFilter(selectedFilter);
      });
    } catch (e) {
      print('Error loading recommendations: $e');
      setState(() {
        recommendations = [];
        filteredRecommendations = [];
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      switch (filter) {
        case 'Open now':
          filteredRecommendations = recommendations
              .where((place) => place['is_open'] == true)
              .toList();
          break;
        case '24 hours':
          filteredRecommendations = recommendations
              .where((place) =>
                  place['opening_hours']?.any((period) =>
                      period['open']['day'] == period['close']['day'] &&
                      period['open']['time'] == '0000' &&
                      period['close']['time'] == '2359') ??
                  false)
              .toList();
          break;
        case 'Any time':
        default:
          filteredRecommendations = List.from(recommendations);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'For you',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.filter_list),
                    onSelected: _applyFilter,
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'Open now',
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 18),
                            SizedBox(width: 8),
                            Text('Open now'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'Any time',
                        child: Row(
                          children: [
                            Icon(Icons.all_inclusive, size: 18),
                            SizedBox(width: 8),
                            Text('Any time'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: '24 hours',
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 18),
                            SizedBox(width: 8),
                            Text('24 hours'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredRecommendations.isEmpty
                  ? Center(child: Text('No recommendations found'))
                  : ListView.builder(
                      itemCount: filteredRecommendations.length,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      physics: ClampingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final place = filteredRecommendations[index];
                        return _buildPlaceCard(place);
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1,
        userEmail: widget.userEmail,
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
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
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              image: DecorationImage(
                image: NetworkImage(
                    place['image'] ?? 'https://via.placeholder.com/400'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['location'] ?? 'Unknown location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16),
                    SizedBox(width: 4),
                    Text(place['is_open'] == true ? 'Open now' : 'Closed'),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // TODO: Implement add to trip
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add to my trip'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TourDetailsPage(tourData: place),
                          ),
                        );
                      },
                      child: Text('More Details'),
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
