import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';
import 'services/recommendation_service.dart';
import 'tour_details_page.dart';
import 'tripPlan.dart';
import 'services/recommendation_cache_service.dart';

class RecommendationPage extends StatefulWidget {
  final String userEmail;

  const RecommendationPage({Key? key, required this.userEmail})
      : super(key: key);

  @override
  _RecommendationPageState createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final RecommendationService _recommendationService = RecommendationService();
  final RecommendationCacheService _cacheService = RecommendationCacheService();
  List<Map<String, dynamic>> recommendations = [];
  List<Map<String, dynamic>> filteredRecommendations = [];
  String selectedFilter = 'Any time';

  @override
  void initState() {
    super.initState();
    _loadCachedRecommendations();
    _refreshRecommendations();
  }

  Future<void> _loadCachedRecommendations() async {
    final cached = await _cacheService.getCachedRecommendations();
    if (cached.isNotEmpty) {
      setState(() {
        recommendations = cached;
        _applyFilter(selectedFilter);
      });
    }
  }

  Future<void> _refreshRecommendations() async {
    try {
      if (!_cacheService.needsRefresh && recommendations.isNotEmpty) {
        return;
      }

      final recs =
          await _recommendationService.getRecommendations(widget.userEmail);

      if (!_areRecommendationsEqual(recs, recommendations)) {
        setState(() {
          recommendations = recs;
          _applyFilter(selectedFilter);
        });
        await _cacheService.cacheRecommendations(recs);
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    }
  }

  bool _areRecommendationsEqual(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]['place_id'] != b[i]['place_id']) return false;
    }
    return true;
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
              child: RefreshIndicator(
                onRefresh: _refreshRecommendations,
                child: filteredRecommendations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: filteredRecommendations.length,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        physics: AlwaysScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final place = filteredRecommendations[index];
                          return _buildPlaceCard(place);
                        },
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'No recommendations found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshRecommendations,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
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
                onError: (_, __) {
                  print('Error loading image for ${place['name']}');
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['name'] ?? 'Unknown location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                if (place['location'] != null) ...[
                  Text(
                    place['location'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16),
                    SizedBox(width: 4),
                    Text(place['is_open'] == true ? 'Open now' : 'Closed'),
                    if (place['rating'] != null) ...[
                      SizedBox(width: 16),
                      Icon(Icons.star, size: 16, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(place['rating'].toString()),
                    ],
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        // Navigate to TripPlan and add the new location
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripPlanPage(
                              userEmail: widget.userEmail,
                              initialPlace: {
                                'place_id': place['place_id'],
                                'name': place['name'],
                              },
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.add),
                      label: Text('Add to my trip'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TourDetailsPage(
                              tourData: place,
                              userEmail: widget.userEmail,
                            ),
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
