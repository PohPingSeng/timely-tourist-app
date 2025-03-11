import 'package:flutter/material.dart';
import 'widgets/custom_bottom_nav.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PopularPlacesPage extends StatefulWidget {
  final String userEmail;

  const PopularPlacesPage({Key? key, required this.userEmail})
      : super(key: key);

  @override
  _PopularPlacesPageState createState() => _PopularPlacesPageState();
}

class _PopularPlacesPageState extends State<PopularPlacesPage> {
  final String apiKey = 'AIzaSyD5fitoSIC-JDcKSTEOvnT0Yt-WF9NxvqQ';
  List<Map<String, dynamic>> places = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPlaces();
  }

  Future<void> fetchPlaces() async {
    final List<Map<String, String>> placeNames = [
      {'name': 'Mount Fuji', 'country': 'Japan'},
      {'name': 'Bali Beach', 'country': 'Indonesia'},
      {'name': 'Swiss Alps', 'country': 'Switzerland'},
      {'name': 'Grand Canyon', 'country': 'USA'},
      {'name': 'Eiffel Tower', 'country': 'France'},
      {'name': 'Great Wall', 'country': 'China'},
      {'name': 'Taj Mahal', 'country': 'India'},
      {'name': 'Machu Picchu', 'country': 'Peru'},
      {'name': 'Santorini', 'country': 'Greece'},
      {'name': 'Venice', 'country': 'Italy'}
    ];

    for (var place in placeNames) {
      try {
        final searchResponse = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${place['name']}&key=$apiKey'));

        if (searchResponse.statusCode == 200) {
          final searchData = json.decode(searchResponse.body);
          if (searchData['results'].isNotEmpty) {
            final result = searchData['results'][0];
            String photoUrl;

            if (result['photos'] != null && result['photos'].isNotEmpty) {
              final photoReference = result['photos'][0]['photo_reference'];
              photoUrl =
                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoReference&key=$apiKey';
            } else {
              // Fallback image if no photo available
              photoUrl =
                  'https://via.placeholder.com/400x300?text=${place['name']}';
            }

            setState(() {
              places.add({
                'name': result['name'],
                'address': result['formatted_address'],
                'rating': result['rating']?.toString() ?? 'N/A',
                'photoUrl': photoUrl,
              });
            });
          }
        }
      } catch (e) {
        print('Error fetching place data: $e');
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Popular Places'),
        backgroundColor: Colors.blue[800],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return Card(
                  elevation: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (place['photoUrl'] != null)
                        Container(
                          height: 200,
                          width: double.infinity,
                          child: Image.network(
                            place['photoUrl']!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(child: CircularProgressIndicator());
                            },
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place['name'],
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              place['address'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.star, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(place['rating']),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 0,
        userEmail: widget.userEmail,
      ),
    );
  }
}