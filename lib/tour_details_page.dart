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
    _fetchPlaceDetails();
  }

  Future<void> _fetchPlaceDetails() async {
    try {
      final placeId = widget.tourData['place_id'];
      if (placeId != null) {
        final result = await _places.getDetailsByPlaceId(placeId);
        if (result.status == 'OK') {
          setState(() => _placeDetails = result.result);
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
                _buildDescription(),
                _buildTicketInfo(),
                _buildExperience(),
                _buildIncludesExcludes(),
                _buildNotSuitableFor(),
                _buildMeetingPoint(),
                _buildImportantInfo(),
                _buildReviews(),
                _buildSuggestedTours(),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tourData['location'] ?? 'Tour Title',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              Text('4.5'),
              Text(' (123 reviews)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticket Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildInfoItem(Icons.access_time,
              'Duration: ${widget.tourData['duration'] ?? 'Not specified'}'),
          _buildInfoItem(
              Icons.payment, 'Cancellation: Free cancellation available'),
          _buildInfoItem(
              Icons.credit_card, 'Payment: Multiple options available'),
        ],
      ),
    );
  }

  Widget _buildExperience() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Experience',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(widget.tourData['experience'] ??
              'Experience details not available'),
        ],
      ),
    );
  }

  Widget _buildIncludesExcludes() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s Included/Excluded',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildList('Includes', widget.tourData['includes'] ?? []),
          const SizedBox(height: 8),
          _buildList('Excludes', widget.tourData['excludes'] ?? []),
        ],
      ),
    );
  }

  Widget _buildNotSuitableFor() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Not Suitable For',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildList('', widget.tourData['not_suitable_for'] ?? []),
        ],
      ),
    );
  }

  Widget _buildMeetingPoint() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meeting Point',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildInfoItem(
              Icons.location_on,
              widget.tourData['meeting_point'] ??
                  'Meeting point not specified'),
        ],
      ),
    );
  }

  Widget _buildImportantInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Important Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildList('', widget.tourData['important_info'] ?? []),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reviews',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          // Add review widgets here
        ],
      ),
    );
  }

  Widget _buildSuggestedTours() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar Tours',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          // Add suggested tours list here
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildList(String title, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
        ],
        ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.toString())),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final photos = _placeDetails?.photos ?? [];
    final photoUrls = photos
        .map((photo) =>
            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${photo.photoReference}&key=$_placesApiKey')
        .toList();

    return Column(
      children: [
        Container(
          height: 200,
          child: PageView.builder(
            itemCount: photoUrls.isEmpty ? 1 : photoUrls.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              return Image.network(
                photoUrls.isEmpty
                    ? (widget.tourData['image'] ??
                        'https://via.placeholder.com/400')
                    : photoUrls[index],
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            photoUrls.isEmpty ? 1 : photoUrls.length,
            (index) => Container(
              margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About This Tour',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 8),
          Text(widget.tourData['description'] ?? 'No description available'),
        ],
      ),
    );
  }
}
