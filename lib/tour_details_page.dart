import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TourDetailsPage extends StatefulWidget {
  final Map<String, dynamic> tourData;
  final String userEmail;

  const TourDetailsPage({
    Key? key,
    required this.tourData,
    required this.userEmail,
  }) : super(key: key);

  @override
  _TourDetailsPageState createState() => _TourDetailsPageState();
}

class _TourDetailsPageState extends State<TourDetailsPage> {
  int _currentImageIndex = 0;
  bool _isInWishlist = false;
  final _placesApiKey = 'AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts';
  late final GoogleMapsPlaces _places;
  PlaceDetails? _placeDetails;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _places = GoogleMapsPlaces(apiKey: _placesApiKey);
    print('Debug: Initial tourData: ${widget.tourData}');
    _fetchPlaceDetails();
    _checkWishlistStatus();
  }

  Future<void> _fetchPlaceDetails() async {
    try {
      final placeId = widget.tourData['place_id'];
      print('Debug: Fetching details for place_id: $placeId');

      if (placeId != null) {
        final result = await _places.getDetailsByPlaceId(
          placeId,
          fields: [
            'name',
            'formatted_address',
            'formatted_phone_number',
            'geometry',
            'icon',
            'photos',
            'place_id',
            'price_level',
            'rating',
            'user_ratings_total',
            'types',
            'url',
            'utc_offset',
            'vicinity',
            'website',
            'opening_hours',
            'address_components',
          ],
        );

        if (result.status == 'OK') {
          final placeJson = result.result.toJson();
          print('Debug: Place details fetched: $placeJson');

          setState(() {
            _placeDetails = result.result;
            widget.tourData.addAll({
              'user_ratings_total': placeJson['user_ratings_total'],
              'formatted_address': placeJson['formatted_address'],
              'types': placeJson['types'],
              'photos': placeJson['photos'],
              'website': placeJson['website'],
              'formatted_phone_number': placeJson['formatted_phone_number'],
              'opening_hours': placeJson['opening_hours'],
              'price_level': placeJson['price_level'],
            });
          });
        }
      }
    } catch (e) {
      print('Error fetching place details: $e');
    }
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final userDoc = await _firestore
          .collection('ttsUser')
          .doc('UID')
          .collection('UID')
          .doc(widget.userEmail) // Use email as document ID
          .get();

      if (userDoc.exists) {
        final wishlist = userDoc.get('wishlist') ?? [];
        setState(() {
          _isInWishlist = wishlist.contains(widget.tourData['place_id']);
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
    }
  }

  Future<void> _toggleWishlist() async {
    try {
      final placeId = widget.tourData['place_id'];
      final userEmail = widget.userEmail;

      print('Debug: Attempting to toggle wishlist for place: $placeId');

      // First, try to save place data
      try {
        await _firestore.collection('places').doc(placeId).set({
          'place_id': placeId,
          'name': widget.tourData['name'],
          'location': widget.tourData['location'],
          'image': widget.tourData['image'],
          'rating': widget.tourData['rating'],
          'is_open': widget.tourData['is_open'],
        }, SetOptions(merge: true));
        print('Debug: Place data saved successfully');
      } catch (e) {
        print('Debug: Error saving place data: $e');
        throw e;
      }

      // Then update wishlist
      try {
        final userDocRef = _firestore
            .collection('ttsUser')
            .doc('UID')
            .collection('UID')
            .doc(userEmail);

        final userDoc = await userDocRef.get();
        List<String> wishlist = [];

        if (userDoc.exists) {
          wishlist = List<String>.from(userDoc.get('wishlist') ?? []);
        }

        if (_isInWishlist) {
          wishlist.remove(placeId);
        } else {
          wishlist.add(placeId);
        }

        print('Debug: Updating wishlist: $wishlist');

        await userDocRef.set({
          'email': userEmail,
          'wishlist': wishlist,
        }, SetOptions(merge: true));

        setState(() {
          _isInWishlist = !_isInWishlist;
        });
        print('Debug: Wishlist updated successfully');
      } catch (e) {
        print('Debug: Error updating wishlist: $e');
        throw e;
      }
    } catch (e) {
      print('Error toggling wishlist: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update wishlist'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _places.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildImageCarousel(),
                _buildLocationDetails(),
                _buildAboutSection(),
                _buildNearbyPlaces(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      floating: false,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isInWishlist ? Icons.favorite : Icons.favorite_border,
            color: _isInWishlist ? Colors.red[300] : null,
          ),
          onPressed: _toggleWishlist,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            Share.share(
                'Check out this amazing tour: ${widget.tourData['location']}');
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final locationName =
        widget.tourData['name'] ?? _placeDetails?.name ?? 'Unknown Location';

    final rating = widget.tourData['rating']?.toString() ??
        _placeDetails?.rating?.toString() ??
        'N/A';

    final totalReviews =
        widget.tourData['user_ratings_total']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(locationName, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          if (rating != 'N/A') ...[
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                Text('$rating'),
                Text(' ($totalReviews reviews)'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationDetails() {
    if (_placeDetails == null) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Location Details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // Place Type
          if (_placeDetails!.types.isNotEmpty)
            _buildInfoItem(
              Icons.category,
              'Type: ${_placeDetails!.types.map((t) => t.replaceAll('_', ' ')).join(', ')}',
            ),
          const SizedBox(height: 8),
          // Address
          if (_placeDetails!.formattedAddress != null)
            _buildInfoItem(
              Icons.place,
              _placeDetails!.formattedAddress!,
            ),
          const SizedBox(height: 8),
          // Coordinates
          if (_placeDetails!.geometry != null)
            _buildInfoItem(
              Icons.location_on,
              'Location: ${_placeDetails!.geometry!.location.lat.toStringAsFixed(6)}, ${_placeDetails!.geometry!.location.lng.toStringAsFixed(6)}',
            ),
          const SizedBox(height: 16),
          // Contact Details
          if (_placeDetails!.formattedPhoneNumber != null ||
              _placeDetails!.website != null) ...[
            Text('Contact', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_placeDetails!.formattedPhoneNumber != null)
              _buildInfoItem(Icons.phone, _placeDetails!.formattedPhoneNumber!),
            if (_placeDetails!.website != null)
              _buildInfoItem(Icons.language, _placeDetails!.website!),
          ],
          const SizedBox(height: 16),
          // Opening Hours
          if (_placeDetails!.openingHours?.weekdayText != null) ...[
            Text('Opening Hours',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...(_placeDetails!.openingHours!.weekdayText!.map(
              (hours) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(hours),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    if (_placeDetails == null) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(_placeDetails!.name),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildImageCarousel() {
    return FutureBuilder<List<String>>(
      future: _getPlacePhotos(),
      builder: (context, snapshot) {
        final photoUrls = snapshot.data ?? [];
        if (photoUrls.isEmpty && widget.tourData['image'] != null) {
          photoUrls.add(widget.tourData['image']);
        }

        return Column(
          children: [
            Container(
              height: 250,
              child: PageView.builder(
                itemCount: photoUrls.isEmpty ? 1 : photoUrls.length,
                onPageChanged: (index) =>
                    setState(() => _currentImageIndex = index),
                itemBuilder: (context, index) {
                  if (photoUrls.isEmpty) {
                    return _buildPlaceholderImage();
                  }

                  return Hero(
                    tag: 'place_image_$index',
                    child: GestureDetector(
                      onTap: () =>
                          _showFullScreenImage(context, photoUrls, index),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Image.network(
                          photoUrls[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (photoUrls.isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  photoUrls.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentImageIndex == index
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.image, size: 50, color: Colors.grey),
      ),
    );
  }

  Future<List<String>> _getPlacePhotos() async {
    if (_placeDetails?.photos == null) return [];

    List<String> photoUrls = [];
    for (var photo in _placeDetails!.photos!) {
      final url = 'https://maps.googleapis.com/maps/api/place/photo'
          '?maxwidth=800'
          '&photoreference=${photo.photoReference}'
          '&key=$_placesApiKey';
      photoUrls.add(url);
    }
    return photoUrls;
  }

  void _showFullScreenImage(
      BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: images.length,
                  controller: PageController(initialPage: initialIndex),
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: Hero(
                        tag: 'place_image_$index',
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyPlaces() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You might also like...',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTourCard(
                  image: 'https://example.com/food-tour.jpg',
                  title:
                      'Kuala Lumpur: Sambal Street Food Tour with 15+ Tastings',
                  duration: '4 hours',
                  groupType: 'Small group',
                  rating: 4.9,
                  reviewCount: 987,
                  price: 229.90,
                ),
                _buildTourCard(
                  image: 'https://example.com/melaka.jpg',
                  title:
                      'From Kuala Lumpur: Historical Melaka Day Tour with Lunch',
                  duration: '10 hours',
                  groupType: 'Pickup available',
                  rating: 4.4,
                  reviewCount: 2051,
                  price: 170.00,
                ),
                // Add more cards as needed
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTourCard({
    required String image,
    required String title,
    required String duration,
    required String groupType,
    required double rating,
    required int reviewCount,
    required double price,
  }) {
    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                image,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: Icon(Icons.image, size: 50, color: Colors.grey),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tour Type Label
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GUIDED TOUR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // Duration and Group Type
                  Text(
                    '$duration • $groupType',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Rating and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(
                            ' $rating',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ' ($reviewCount)',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      Text(
                        'From RM ${price.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
