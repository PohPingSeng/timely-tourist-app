import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_webservice/places.dart';

class TourDetailsPage extends StatefulWidget {
  final Map<String, dynamic> tourData;

  const TourDetailsPage({Key? key, required this.tourData}) : super(key: key);

  @override
  _TourDetailsPageState createState() => _TourDetailsPageState();
}

class _TourDetailsPageState extends State<TourDetailsPage> {
  int _currentImageIndex = 0;
  bool _isWishlisted = false;
  final _placesApiKey = 'AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts';
  late final GoogleMapsPlaces _places;
  PlaceDetails? _placeDetails;

  @override
  void initState() {
    super.initState();
    _places = GoogleMapsPlaces(apiKey: _placesApiKey);
    print('Debug: Initial tourData: ${widget.tourData}');
    _fetchPlaceDetails();
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
          icon: Icon(_isWishlisted ? Icons.favorite : Icons.favorite_border),
          onPressed: () => setState(() => _isWishlisted = !_isWishlisted),
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
    if (_placeDetails?.geometry?.location == null) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nearby Places', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // TODO: Implement nearby places search
          Text('Coming soon...'),
        ],
      ),
    );
  }
}
