import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'models/trip_location.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'multi_transportation_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Add new transit mode types
enum TransitMode {
  walking,
  cycling,
  driving,
  bus,
  train,
  flight,
  ferry,
  motorcycle
}

class TransitOption {
  final TransitMode mode;
  final String duration;
  final String distance;
  final String price;
  bool isBest;
  final List<dynamic> steps;
  final String polyline;
  final String origin;
  final String destination;
  final String? viaRoute;
  final bool hasTolls;
  final bool isMultiModal;

  TransitOption({
    required this.mode,
    required this.duration,
    required this.distance,
    required this.price,
    required this.isBest,
    required this.steps,
    required this.polyline,
    required this.origin,
    required this.destination,
    this.viaRoute,
    this.hasTolls = false,
    this.isMultiModal = false,
  });

  TransitOption copyWith({
    TransitMode? mode,
    String? duration,
    String? distance,
    String? price,
    bool? isBest,
    List<dynamic>? steps,
    String? polyline,
    String? origin,
    String? destination,
    String? viaRoute,
    bool? hasTolls,
    bool? isMultiModal,
  }) {
    return TransitOption(
      mode: mode ?? this.mode,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      price: price ?? this.price,
      isBest: isBest ?? this.isBest,
      steps: steps ?? this.steps,
      polyline: polyline ?? this.polyline,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      viaRoute: viaRoute ?? this.viaRoute,
      hasTolls: hasTolls ?? this.hasTolls,
      isMultiModal: isMultiModal ?? this.isMultiModal,
    );
  }
}

class TransportationRoutePage extends StatefulWidget {
  final List<TripLocation> locations;
  final String userEmail;
  final Function(TripLocation) onLocationRemoved;
  final Function(List<TripLocation>) onLocationsUpdated;

  const TransportationRoutePage({
    super.key,
    required this.locations,
    required this.userEmail,
    required this.onLocationRemoved,
    required this.onLocationsUpdated,
  });

  @override
  _TransportationRoutePageState createState() =>
      _TransportationRoutePageState();
}

class _TransportationRoutePageState extends State<TransportationRoutePage> {
  final String _apiKey = 'AIzaSyD5fitoSIC-JDcKSTEOvnT0Yt-WF9NxvqQ';
  GoogleMapController? _mapController;
  bool _isMapExpanded = false;
  Set<Marker> _markers = {};
  Set<Polyline> _routes = {};
  Map<String, dynamic> _routeInfo = {};
  bool _isReversed = false;
  List<TransitOption> _transitOptions = [];
  bool _isFetchingRoutes = false;
  String _selectedRouteId = '';
  List<dynamic> _searchResults = [];
  String? _currentTripId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    // Print location data for debugging
    for (var location in widget.locations) {
      print(
          'Location: ${location.name}, LatLng: ${location.latLng.latitude}, ${location.latLng.longitude}');
    }

    _initializeMarkersAsync(reverse: _isReversed).then((_) {
      _fetchRoutes().then((_) {
        // Highlight the best route after fetching routes
        if (_transitOptions.isNotEmpty) {
          final bestRoute = _transitOptions.firstWhere(
              (option) => option.isBest,
              orElse: () => _transitOptions.first);
          _highlightRoute(bestRoute.polyline);
        }
      });
    });
  }

  Future<void> _fetchRoutes() async {
    if (widget.locations.length < 2) return;

    setState(() => _isFetchingRoutes = true);
    _transitOptions.clear();
    _routes.clear();

    try {
      final origin = widget.locations[0];
      final destination = widget.locations[1];

      print('Fetching routes from ${origin.name} to ${destination.name}');

      // Fetch all transit modes in parallel for better performance
      await Future.wait([
        // 1. Fetch driving routes with different preferences
        _fetchDrivingDirections(origin, destination, preferHighways: true),
        _fetchDrivingDirections(origin, destination, preferHighways: false),
        _fetchMotorcycleDirections(origin, destination),

        // 2. Fetch public transit routes
        _fetchPublicTransitRoutes(origin, destination),

        // 3. For longer distances, check flight options
        if (_isLongDistance(origin, destination))
          _fetchFlightOptions(origin, destination),

        // 4. Fetch multi-modal options
        _fetchMultiModalOptions(origin, destination),
      ]);

      // Sort options by duration and price
      _sortAndMarkBestOptions();
    } catch (e) {
      print('Error fetching routes: $e');
    } finally {
      setState(() => _isFetchingRoutes = false);
    }
  }

  Future<void> _fetchDrivingDirections(
      TripLocation origin, TripLocation destination,
      {bool preferHighways = true}) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.travelAdvisory,routes.routeLabels'
    };

    final body = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latLng.latitude,
            "longitude": origin.latLng.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latLng.latitude,
            "longitude": destination.latLng.longitude
          }
        }
      },
      "travelMode": "DRIVE",
      "routingPreference":
          preferHighways ? "TRAFFIC_AWARE" : "TRAFFIC_AWARE_NO_HIGHWAYS",
      "routeModifiers": {
        "avoidTolls": !preferHighways,
        "vehicleInfo": {"emissionType": "GASOLINE"}
      },
      "languageCode": "en-US",
      "units": "METRIC"
    });

    try {
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null) {
          for (var route in data['routes']) {
            // Fix the toll road check
            bool hasTolls = false;
            if (route['travelAdvisory'] != null) {
              final advisories =
                  route['travelAdvisory'] as Map<String, dynamic>;

              // Check for explicit toll road flag
              final hasTollRoads = advisories['tollRoads'] == true;

              // Check warnings list if it exists
              final warnings = advisories['warnings'] as List?;
              final hasTollWarning = warnings?.any((warning) =>
                      warning.toString().toLowerCase().contains('toll')) ??
                  false;

              hasTolls = hasTollRoads || hasTollWarning;
            }

            final viaRoute = preferHighways ? 'via AH2/E1' : 'via local roads';

            _addTransitOption(
                route, TransitMode.driving, origin.name, destination.name,
                viaRoute: viaRoute, hasTolls: hasTolls);
          }
        }
      }
    } catch (e) {
      print('Error fetching driving directions: $e');
    }
  }

  Future<void> _fetchMotorcycleDirections(
      TripLocation origin, TripLocation destination) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.travelAdvisory'
    };

    final body = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latLng.latitude,
            "longitude": origin.latLng.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latLng.latitude,
            "longitude": destination.latLng.longitude
          }
        }
      },
      "travelMode": "TWO_WHEELER",
      "routingPreference": "TRAFFIC_AWARE",
      "computeAlternativeRoutes": true,
      "languageCode": "en-US",
      "units": "METRIC"
    });

    try {
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null) {
          for (var route in data['routes']) {
            _addTransitOption(
                route, TransitMode.motorcycle, origin.name, destination.name,
                viaRoute: route['description'] ?? 'via motorcycle');
          }
        }
      }
    } catch (e) {
      print('Error fetching motorcycle directions: $e');
    }
  }

  Future<void> _fetchPublicTransitRoutes(
      TripLocation origin, TripLocation destination) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.transitDetails,routes.fare,routes.localizedValues'
    };

    // Fetch bus routes with fare data
    final busBody = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latLng.latitude,
            "longitude": origin.latLng.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latLng.latitude,
            "longitude": destination.latLng.longitude
          }
        }
      },
      "travelMode": "TRANSIT",
      "transitPreferences": {
        "allowedTravelModes": ["BUS"],
        "routingPreference": "LESS_WALKING"
      },
      "computeAlternativeRoutes": true,
      "languageCode": "en-US",
      "units": "METRIC",
      "requestedPriceAccuracy": "EXACT" // Request exact fare data
    });

    // Fetch train routes
    final trainBody = jsonEncode({
      // Similar to busBody but with "RAIL" travel mode
      "transitPreferences": {
        "allowedTravelModes": ["RAIL", "SUBWAY", "TRAIN"],
        "routingPreference": "LESS_WALKING"
      },
    });

    try {
      // Fetch both bus and train routes in parallel
      final responses = await Future.wait([
        http.post(Uri.parse(url), headers: headers, body: busBody),
        http.post(Uri.parse(url), headers: headers, body: trainBody)
      ]);

      for (var response in responses) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'] != null) {
            for (var route in data['routes']) {
              final isTrainRoute = route['transitDetails']?['line']?['vehicle']
                      ?['type'] ==
                  'RAIL';

              // Get actual fare from response
              String price = 'Price varies';
              if (route['fare'] != null) {
                final fare = route['fare'];
                price = '${fare['currency']} ${fare['amount']}';
              }

              _addTransitOption(
                  route,
                  isTrainRoute ? TransitMode.train : TransitMode.bus,
                  origin.name,
                  destination.name,
                  price: price, // Pass actual fare
                  viaRoute: _getTransitRouteName(route),
                  isMultiModal: _isMultiModalRoute(route));
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching public transit routes: $e');
    }
  }

  String _getTransitRouteName(Map<String, dynamic> route) {
    final legs = route['legs'] as List?;
    if (legs == null || legs.isEmpty) return '';

    final List<String> transitLines = [];
    for (var leg in legs) {
      final steps = leg['steps'] as List?;
      if (steps != null) {
        for (var step in steps) {
          if (step['transitDetails'] != null) {
            final lineName = step['transitDetails']['line']['shortName'] ??
                step['transitDetails']['line']['name'];
            if (lineName != null && !transitLines.contains(lineName)) {
              transitLines.add(lineName);
            }
          }
        }
      }
    }

    return transitLines.join(' → ');
  }

  bool _isMultiModalRoute(Map<String, dynamic> route) {
    final legs = route['legs'] as List?;
    if (legs == null || legs.isEmpty) return false;

    final Set<String> modes = {};
    for (var leg in legs) {
      final steps = leg['steps'] as List?;
      if (steps != null) {
        for (var step in steps) {
          if (step['travelMode'] != null) {
            modes.add(step['travelMode']);
          }
        }
      }
    }

    return modes.length > 1;
  }

  double _calculateRouteScore(TransitOption option) {
    // Lower score is better
    double score = _parseDuration(option.duration).toDouble();

    // Prefer routes without tolls
    if (option.hasTolls) score += 30;

    // Slight preference for public transit (environmental/cost factor)
    if (option.mode == TransitMode.bus || option.mode == TransitMode.train) {
      score *= 0.95;
    }

    return score;
  }

  String _calculatePrice(
      TransitMode mode, int distanceInMeters, Map<String, dynamic>? routeData,
      {bool hasTolls = false}) {
    // Get fare from API response if available
    if (routeData != null && routeData['fare'] != null) {
      final fare = routeData['fare'];
      return '${fare['currency']} ${fare['amount']}';
    }

    // If no fare data available, return price range
    return 'Price varies';
  }

  void _addTransitOption(
    Map<String, dynamic> route,
    TransitMode mode,
    String origin,
    String destination, {
    String? price,
    String? viaRoute,
    bool hasTolls = false,
    bool isMultiModal = false,
  }) {
    final durationInSeconds =
        int.parse(route['duration'].toString().replaceAll('s', ''));
    final distanceInMeters = int.parse(route['distanceMeters'].toString());

    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;
    final durationText =
        hours > 0 ? '${hours}h ${minutes}min' : '${minutes} mins';

    final distanceKm = (distanceInMeters / 1000).toStringAsFixed(1);
    final distanceText = '$distanceKm km';

    // Use provided price or calculate from route data
    final routePrice = price ??
        _calculatePrice(mode, distanceInMeters, route, hasTolls: hasTolls);

    _transitOptions.add(TransitOption(
      mode: mode,
      duration: durationText,
      distance: distanceText,
      price: routePrice,
      isBest: false,
      steps: route['legs'] ?? [],
      polyline: route['polyline']['encodedPolyline'],
      origin: origin,
      destination: destination,
      viaRoute: viaRoute,
      hasTolls: hasTolls,
      isMultiModal: isMultiModal,
    ));

    _routes.add(_createPolyline(
      '${mode.toString()}_${_transitOptions.length}',
      _decodePolyline(route['polyline']['encodedPolyline']),
      _getModeColor(mode),
    ));
  }

  String _getModeString(TransitMode mode) {
    switch (mode) {
      case TransitMode.walking:
        return 'walking';
      case TransitMode.cycling:
        return 'cycling';
      case TransitMode.driving:
        return 'driving';
      case TransitMode.bus:
        return 'bus';
      case TransitMode.train:
        return 'train';
      case TransitMode.flight:
        return 'flight';
      case TransitMode.ferry:
        return 'ferry';
      case TransitMode.motorcycle:
        return 'motorcycle';
      default:
        return 'unknown'; // Default string
    }
  }

  IconData _getModeIcon(TransitMode mode) {
    switch (mode) {
      case TransitMode.walking:
        return Icons.directions_walk;
      case TransitMode.cycling:
        return Icons.directions_bike;
      case TransitMode.driving:
        return Icons.directions_car;
      case TransitMode.bus:
        return Icons.directions_bus;
      case TransitMode.train:
        return Icons.train;
      case TransitMode.flight:
        return Icons.flight;
      case TransitMode.ferry:
        return Icons.directions_boat;
      case TransitMode.motorcycle:
        return Icons.motorcycle;
      default:
        return Icons.help; // Default icon
    }
  }

  Color _getModeColor(TransitMode mode) {
    switch (mode) {
      case TransitMode.walking:
        return Colors.green;
      case TransitMode.cycling:
        return Colors.orange;
      case TransitMode.driving:
        return Colors.blue;
      case TransitMode.bus:
        return Colors.red;
      case TransitMode.train:
        return Colors.purple;
      case TransitMode.flight:
        return Colors.indigo;
      case TransitMode.ferry:
        return Colors.cyan;
      case TransitMode.motorcycle:
        return Colors.amber;
      default:
        return Colors.grey; // Default color
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Polyline _createPolyline(String id, List<LatLng> points, Color color) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: 4,
    );
  }

  Future<void> _initializeMarkersAsync({bool reverse = false}) async {
    final markers = <Marker>{};
    final locations =
        reverse ? widget.locations.reversed.toList() : widget.locations;

    for (var i = 0; i < locations.length; i++) {
      final location = locations[i];
      final markerIcon = await _createCustomMarkerBytes(i + 1);
      markers.add(
        Marker(
          markerId: MarkerId(location.placeId),
          position: location.latLng,
          icon: BitmapDescriptor.fromBytes(markerIcon),
          infoWindow: InfoWindow(
            title: location.name,
            snippet: 'Stop ${i + 1}',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<Uint8List> _createCustomMarkerBytes(int number) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(40, 40);

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw circle background
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );

    // Draw white border
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      borderPaint,
    );

    // Draw number
    final textPainter = TextPainter(
      text: TextSpan(
        text: number.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  void _fitMapBounds() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (Marker marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
    }

    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            minLat - latPadding,
            minLng - lngPadding,
          ),
          northeast: LatLng(
            maxLat + latPadding,
            maxLng + lngPadding,
          ),
        ),
        50,
      ),
    );
  }

  Widget _buildMapSection() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.locations.first.latLng,
            zoom: 12,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            Future.delayed(Duration(milliseconds: 300), () {
              _fitMapBounds();
            });
          },
          markers: _markers,
          polylines: _routes,
          myLocationEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          zoomGesturesEnabled: true,
        ),
        // Add recenter button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            child: Icon(Icons.center_focus_strong, color: Colors.black87),
            onPressed: _fitMapBounds,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSwitcher() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildLocationField(
                  widget.locations[0],
                  isOrigin: true,
                  onRemove: () => _handleLocationRemoval(widget.locations[0]),
                ),
                SizedBox(height: 8),
                _buildLocationField(
                  widget.locations[1],
                  isOrigin: false,
                  onRemove: () => _handleLocationRemoval(widget.locations[1]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.swap_vert),
            onPressed: _swapLocations,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField(TripLocation location,
      {required bool isOrigin, required Function() onRemove}) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isOrigin ? Icons.trip_origin : Icons.location_on,
                  size: 20,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location.name,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: onRemove,
          color: Colors.grey[600],
        ),
      ],
    );
  }

  Widget _buildRouteTitle() {
    final destinationName =
        _isReversed ? widget.locations.first.name : widget.locations[1].name;
    final originName =
        _isReversed ? widget.locations[1].name : widget.locations.first.name;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        '${_transitOptions.length} ways to travel from $originName to $destinationName',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRouteCard({
    required IconData icon,
    required String mode,
    required String duration,
    required String distance,
    required String price,
    required bool isBest,
    required String origin,
    required String destination,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Show route details
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: isBest ? Colors.blue : Colors.grey[600]),
                    SizedBox(width: 8),
                    Text(
                      mode.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isBest ? Colors.blue : Colors.grey[800],
                      ),
                    ),
                    if (isBest) ...[
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BEST OPTION',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    Spacer(),
                    Text(
                      price,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$origin → $destination',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$duration • $distance',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteOptions() {
    if (_isFetchingRoutes) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_transitOptions.isEmpty) {
      return Center(
        child: Text('No routes found. Try different locations.'),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _transitOptions.length,
      itemBuilder: (context, index) {
        final option = _transitOptions[index];

        // Determine if this is a multi-modal option
        bool isMultiModal = option.mode == TransitMode.bus &&
            option.origin != option.destination &&
            option.distance.contains('km') &&
            double.parse(option.distance.split(' ')[0]) > 100;

        // Check if this route is selected
        final isSelected = _selectedRouteId.isNotEmpty &&
            _routes.isNotEmpty &&
            _routes.first.points.toString() ==
                _decodePolyline(option.polyline).toString();

        return InkWell(
          onTap: () {
            _highlightRoute(option.polyline);
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // First row: Transport mode icons and title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transport mode icon(s)
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: isMultiModal
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_bus,
                                    color: Colors.red, size: 18),
                                Icon(Icons.flight,
                                    color: Colors.indigo, size: 18),
                              ],
                            )
                          : Icon(
                              _getModeIcon(option.mode),
                              color: _getModeColor(option.mode),
                              size: 24,
                            ),
                    ),
                    SizedBox(width: 16),

                    // Title and BEST tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with BEST tag
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(
                                isMultiModal
                                    ? 'Bus to airport, fly to ${option.destination}'
                                    : option.mode == TransitMode.flight
                                        ? 'Fly to ${option.destination}'
                                        : _getModeString(option.mode)
                                            .capitalize(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (option.isBest)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'BEST',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Duration and distance
                          SizedBox(height: 4),
                          Text(
                            '${option.duration} • ${option.distance}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Second row: Price and arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      option.price,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransportIcons(TransitMode mode) {
    // For combined modes like "Taxi, bus, subway"
    if (mode == TransitMode.bus) {
      return Row(
        children: [
          Icon(Icons.local_taxi, color: Colors.amber),
          Icon(Icons.directions_bus, color: Colors.red),
          Icon(Icons.subway, color: Colors.purple),
        ],
      );
    } else if (mode == TransitMode.train) {
      return Row(
        children: [
          Icon(Icons.train, color: Colors.purple),
          Icon(Icons.directions_bus, color: Colors.red),
        ],
      );
    } else {
      return Icon(_getModeIcon(mode), color: _getModeColor(mode));
    }
  }

  void _highlightRoute(String polyline) {
    // Create a new set of routes with only the selected route
    final selectedRoute = _transitOptions.firstWhere(
      (option) => option.polyline == polyline,
      orElse: () => _transitOptions.first,
    );

    // Generate a unique ID for this route
    final routeId =
        '${selectedRoute.mode.toString()}_${DateTime.now().millisecondsSinceEpoch}';
    _selectedRouteId = routeId;

    // Create a new set of polylines with just the selected route
    final newRoutes = <Polyline>{};
    newRoutes.add(
      Polyline(
        polylineId: PolylineId(routeId),
        points: _decodePolyline(polyline),
        color: _getModeColor(selectedRoute.mode),
        width: 6, // Make the selected route thicker
      ),
    );

    setState(() {
      _routes = newRoutes;
    });
  }

  Widget _buildAddDestination() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Show search for new destination
            final result = await _showAddDestinationSearch();
            if (result != null) {
              // If a new location was added and we now have more than 2 locations
              if (widget.locations.length > 2) {
                // Navigate to MultiTransportationRoutePage
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MultiTransportationRoutePage(
                      locations: widget.locations,
                      userEmail: widget.userEmail,
                      onLocationRemoved: widget.onLocationRemoved,
                      onLocationsUpdated: widget.onLocationsUpdated,
                    ),
                  ),
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue),
                SizedBox(width: 16),
                Text(
                  'Add Destination',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<TripLocation?> _showAddDestinationSearch() async {
    TripLocation? newLocation;
    bool showResults = false;
    List<dynamic> searchResults = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search for a place',
                          border: InputBorder.none,
                        ),
                        onChanged: (query) async {
                          if (query.trim().isEmpty) {
                            setModalState(() {
                              searchResults = [];
                              showResults = false;
                            });
                          } else {
                            try {
                              final response = await http.get(
                                Uri.parse(
                                    'https://maps.googleapis.com/maps/api/place/autocomplete/json'
                                    '?input=${Uri.encodeComponent(query)}'
                                    '&key=$_apiKey'
                                    '&components=country:my'),
                              );

                              if (response.statusCode == 200) {
                                final data = json.decode(response.body);
                                setModalState(() {
                                  searchResults = data['predictions'];
                                  showResults = true;
                                });
                              }
                            } catch (e) {
                              print('Error searching places: $e');
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              if (showResults)
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final place = searchResults[index];
                      return ListTile(
                        dense: true,
                        title: Text(place['description']),
                        onTap: () async {
                          try {
                            final response = await http.get(
                              Uri.parse(
                                  'https://maps.googleapis.com/maps/api/place/details/json'
                                  '?place_id=${place['place_id']}'
                                  '&fields=name,geometry,formatted_address'
                                  '&key=$_apiKey'),
                            );

                            if (response.statusCode == 200) {
                              final data = json.decode(response.body);
                              final result = data['result'];

                              newLocation = TripLocation(
                                placeId: place['place_id'],
                                name: result['name'],
                                address: result['formatted_address'],
                                latLng: LatLng(
                                  result['geometry']['location']['lat'],
                                  result['geometry']['location']['lng'],
                                ),
                              );

                              // Add to locations list
                              widget.locations.add(newLocation!);

                              // Sync with parent and database
                              widget.onLocationsUpdated(widget.locations);

                              // If we now have more than 2 locations, navigate to MultiTransportationRoutePage
                              if (widget.locations.length > 2) {
                                // Replace the current page with MultiTransportationRoutePage and clear the stack
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MultiTransportationRoutePage(
                                      locations: widget.locations,
                                      userEmail: widget.userEmail,
                                      onLocationRemoved:
                                          widget.onLocationRemoved,
                                      onLocationsUpdated:
                                          widget.onLocationsUpdated,
                                    ),
                                  ),
                                  (route) => route
                                      .isFirst, // Keep only the first route (TripPlanPage)
                                );
                              } else {
                                // Otherwise just close the bottom sheet
                                Navigator.pop(context, newLocation);
                              }
                            }
                          } catch (e) {
                            print('Error getting place details: $e');
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return newLocation;
  }

  void _handleLocationRemoval(TripLocation location) async {
    try {
      // Remove the location and update parent
      widget.onLocationRemoved(location);
      widget.onLocationsUpdated(widget.locations);

      // Update the database
      if (_currentTripId != null) {
        await _firestore.collection('trips').doc(_currentTripId).update({
          'locations': widget.locations.map((loc) => loc.toMap()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // If no locations left or only one location remains, navigate back
      if (widget.locations.length < 2) {
        Navigator.pop(context);
      } else {
        // Refresh routes with remaining locations
        await _fetchRoutes();
      }
    } catch (e) {
      print('Error removing location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove location')),
      );
    }
  }

  Future<double> _calculateDistance(LatLng origin, LatLng destination) async {
    final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/distancematrix/json'
            '?origins=${origin.latitude},${origin.longitude}'
            '&destinations=${destination.latitude},${destination.longitude}'
            '&key=$_apiKey'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['rows'][0]['elements'][0]['status'] == 'OK') {
        return data['rows'][0]['elements'][0]['distance']['value'] /
            1000; // Convert to km
      }
    }

    // Fallback: Calculate straight-line distance
    return _calculateStraightLineDistance(origin, destination);
  }

  double _calculateStraightLineDistance(LatLng origin, LatLng destination) {
    const double earthRadius = 6371; // km
    final lat1 = origin.latitude * pi / 180;
    final lon1 = origin.longitude * pi / 180;
    final lat2 = destination.latitude * pi / 180;
    final lon2 = destination.longitude * pi / 180;

    final dLat = (destination.latitude - origin.latitude) * pi / 180;
    final dLon = (destination.longitude - origin.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance;
  }

  int _parseDuration(String duration) {
    // Convert duration string (e.g., "1 hour 30 mins" or "45 mins") to minutes
    final parts = duration.toLowerCase().split(' ');
    int minutes = 0;

    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == 'hour' || parts[i] == 'hours') {
        minutes += int.parse(parts[i - 1]) * 60;
      } else if (parts[i] == 'min' || parts[i] == 'mins') {
        minutes += int.parse(parts[i - 1]);
      }
    }

    return minutes;
  }

  // Add this method to generate mock data
  void _addMockRoutes() {
    if (_transitOptions.isEmpty) {
      print('Adding mock routes for testing');

      // Get the start and end points
      final origin = widget.locations.first;
      final destination = widget.locations[1];

      // Check if flight is needed
      bool flightNeeded = _isFlightNeeded(origin, destination);

      // Calculate distance
      final distanceInKm =
          _calculateStraightLineDistance(origin.latLng, destination.latLng);

      if (flightNeeded) {
        // Create mock polylines for different routes
        final flightPolyline =
            _createMockPolyline(origin.latLng, destination.latLng, 0);
        final busFlightPolyline =
            _createMockPolyline(origin.latLng, destination.latLng, 0.02);

        // Flight duration (assuming 800 km/h average speed)
        final flightDurationMinutes = (distanceInKm / 800 * 60).round();
        final flightHours = flightDurationMinutes ~/ 60;
        final flightMinutes = flightDurationMinutes % 60;
        final flightTimeFormatted = flightHours > 0
            ? '${flightHours}h ${flightMinutes}min'
            : '${flightMinutes} mins';

        // Bus to airport + flight duration
        final busFlightDurationMinutes = flightDurationMinutes +
            180; // 3 hours for bus and airport procedures
        final busFlightHours = busFlightDurationMinutes ~/ 60;
        final busFlightMinutes = busFlightDurationMinutes % 60;
        final busFlightTimeFormatted =
            '${busFlightHours}h ${busFlightMinutes}min';

        // Add direct flight option
        _transitOptions.add(TransitOption(
          mode: TransitMode.flight,
          duration: flightTimeFormatted,
          distance: '$distanceInKm km',
          price:
              'MYR${(distanceInKm * 0.15).round()}-${(distanceInKm * 0.2).round()}',
          isBest: true,
          steps: [],
          polyline: flightPolyline,
          origin: origin.name,
          destination: destination.name,
        ));

        // Add route polyline to map
        _routes.add(_createPolyline(
          'flight',
          _decodePolyline(flightPolyline),
          Colors.indigo,
        ));

        // Add bus + flight option
        _transitOptions.add(TransitOption(
          mode: TransitMode.bus, // We'll customize the display in the UI
          duration: busFlightTimeFormatted,
          distance: '$distanceInKm km',
          price:
              'MYR${(distanceInKm * 0.15 + 10).round()}-${(distanceInKm * 0.2 + 10).round()}',
          isBest: false,
          steps: [],
          polyline: busFlightPolyline,
          origin: origin.name,
          destination: destination.name,
        ));

        // Add route polyline to map
        _routes.add(_createPolyline(
          'busFlight',
          _decodePolyline(busFlightPolyline),
          Colors.deepOrange,
        ));
      } else {
        // For shorter distances, use the existing mock data approach
        // Create mock polylines for different routes
        final drivingPolyline =
            _createMockPolyline(origin.latLng, destination.latLng, 0.01);
        final busPolyline =
            _createMockPolyline(origin.latLng, destination.latLng, -0.01);
        final trainPolyline =
            _createMockPolyline(origin.latLng, destination.latLng, 0.02);

        // Format times based on distance
        final drivingTimeMinutes = (distanceInKm / 60 * 60).round(); // 60 km/h
        final busTimeMinutes = (distanceInKm / 40 * 60).round(); // 40 km/h
        final trainTimeMinutes = (distanceInKm / 80 * 60).round(); // 80 km/h

        final drivingHours = drivingTimeMinutes ~/ 60;
        final drivingMinutes = drivingTimeMinutes % 60;
        final drivingTimeFormatted = drivingHours > 0
            ? '${drivingHours}h ${drivingMinutes}min'
            : '${drivingMinutes} mins';

        final busHours = busTimeMinutes ~/ 60;
        final busMinutes = busTimeMinutes % 60;
        final busTimeFormatted = busHours > 0
            ? '${busHours}h ${busMinutes}min'
            : '${busMinutes} mins';

        final trainHours = trainTimeMinutes ~/ 60;
        final trainMinutes = trainTimeMinutes % 60;
        final trainTimeFormatted = trainHours > 0
            ? '${trainHours}h ${trainMinutes}min'
            : '${trainMinutes} mins';

        // Add driving option
        _transitOptions.add(TransitOption(
          mode: TransitMode.driving,
          duration: drivingTimeFormatted,
          distance: '$distanceInKm km',
          price:
              'MYR${(5 + distanceInKm * 0.8).round()}-${(5 + distanceInKm * 1.2).round()}',
          isBest: true,
          steps: [],
          polyline: drivingPolyline,
          origin: origin.name,
          destination: destination.name,
        ));

        // Add route polyline to map
        _routes.add(_createPolyline(
          'driving',
          _decodePolyline(drivingPolyline),
          Colors.blue,
        ));

        // Add bus option
        _transitOptions.add(TransitOption(
          mode: TransitMode.bus,
          duration: busTimeFormatted,
          distance: '$distanceInKm km',
          price:
              'MYR${(2 + distanceInKm * 0.15).round()}-${(2 + distanceInKm * 0.2).round()}',
          isBest: false,
          steps: [],
          polyline: busPolyline,
          origin: origin.name,
          destination: destination.name,
        ));

        // Add route polyline to map
        _routes.add(_createPolyline(
          'bus',
          _decodePolyline(busPolyline),
          Colors.red,
        ));

        // Add train option
        _transitOptions.add(TransitOption(
          mode: TransitMode.train,
          duration: trainTimeFormatted,
          distance: '$distanceInKm km',
          price:
              'MYR${(5 + distanceInKm * 0.18).round()}-${(5 + distanceInKm * 0.25).round()}',
          isBest: false,
          steps: [],
          polyline: trainPolyline,
          origin: origin.name,
          destination: destination.name,
        ));

        // Add route polyline to map
        _routes.add(_createPolyline(
          'train',
          _decodePolyline(trainPolyline),
          Colors.purple,
        ));
      }
    }
  }

  // Helper method to create a mock polyline between two points
  String _createMockPolyline(LatLng start, LatLng end, double offset) {
    // Create a slightly curved path between the two points
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2 + offset;

    final points = [start, LatLng(midLat, midLng), end];

    return _encodePolyline(points);
  }

  // Encode a list of LatLng points into a polyline string
  String _encodePolyline(List<LatLng> points) {
    final result = StringBuffer();
    int lastLat = 0;
    int lastLng = 0;

    for (final point in points) {
      final lat = (point.latitude * 1e5).round();
      final lng = (point.longitude * 1e5).round();

      _encodeValue(result, lat - lastLat);
      _encodeValue(result, lng - lastLng);

      lastLat = lat;
      lastLng = lng;
    }

    return result.toString();
  }

  void _encodeValue(StringBuffer result, int value) {
    int v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      result.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    result.writeCharCode(v + 63);
  }

  // Add this method to determine if flight is needed based on distance and location type
  bool _isFlightNeeded(TripLocation origin, TripLocation destination) {
    // Calculate straight-line distance
    final distance =
        _calculateStraightLineDistance(origin.latLng, destination.latLng);

    // If distance is greater than 500km, suggest flight
    if (distance > 500) {
      return true;
    }

    // Check if locations are on different landmasses (simplified approach)
    // In a real implementation, you would use a more sophisticated method to detect islands
    // For now, we'll use a simple check based on known island locations in Malaysia
    bool isOriginIsland = _isIslandLocation(origin.name);
    bool isDestinationIsland = _isIslandLocation(destination.name);

    // If one is on mainland and other is on island, flight is needed
    if (isOriginIsland != isDestinationIsland) {
      return true;
    }

    // If both are on different islands, flight is needed
    if (isOriginIsland &&
        isDestinationIsland &&
        !_areOnSameIsland(origin.name, destination.name)) {
      return true;
    }

    return false;
  }

  // Helper method to check if a location is on an island
  bool _isIslandLocation(String locationName) {
    // List of known island locations in Malaysia
    final islandLocations = [
      'sabah', 'kota kinabalu', 'sandakan', 'tawau', 'lahad datu', // Borneo
      'sarawak', 'kuching', 'miri', 'sibu', // Borneo
      'penang', 'georgetown', // Penang Island
      'langkawi', // Langkawi Island
      'tioman', // Tioman Island
      'perhentian', // Perhentian Islands
      'redang', // Redang Island
    ];

    return islandLocations
        .any((island) => locationName.toLowerCase().contains(island));
  }

  // Helper method to check if two island locations are on the same island
  bool _areOnSameIsland(String location1, String location2) {
    // Borneo locations (Sabah and Sarawak)
    final borneoLocations = [
      'sabah',
      'kota kinabalu',
      'sandakan',
      'tawau',
      'lahad datu',
      'sarawak',
      'kuching',
      'miri',
      'sibu',
    ];

    // Penang locations
    final penangLocations = ['penang', 'georgetown'];

    // Langkawi locations
    final langkawiLocations = ['langkawi'];

    // Check if both locations are on the same island
    if (borneoLocations.any((loc) => location1.toLowerCase().contains(loc)) &&
        borneoLocations.any((loc) => location2.toLowerCase().contains(loc))) {
      return true;
    }

    if (penangLocations.any((loc) => location1.toLowerCase().contains(loc)) &&
        penangLocations.any((loc) => location2.toLowerCase().contains(loc))) {
      return true;
    }

    if (langkawiLocations.any((loc) => location1.toLowerCase().contains(loc)) &&
        langkawiLocations.any((loc) => location2.toLowerCase().contains(loc))) {
      return true;
    }

    return false;
  }

  // Add a method to fetch flight options
  Future<bool> _fetchFlightOptions(
      TripLocation origin, TripLocation destination) async {
    // Use a flight search API like Amadeus, Skyscanner, or your preferred provider
    final url = 'YOUR_FLIGHT_API_ENDPOINT';

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'YOUR_FLIGHT_API_KEY',
        // Other required headers
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Process real flight data and add flight options
        // This will vary based on which flight API you use
      }
    } catch (e) {
      print('Error fetching flight options: $e');
    }

    return true;
  }

  // Add a method to fetch multi-modal options (e.g., bus to airport, then flight)
  Future<bool> _fetchMultiModalOptions(
      TripLocation origin, TripLocation destination) async {
    // In a real implementation, you would use a combination of APIs
    // For now, we'll create a mock multi-modal option

    final distance =
        _calculateStraightLineDistance(origin.latLng, destination.latLng);

    // Bus to airport duration (estimated)
    final busDuration = 60; // 1 hour to airport

    // Flight duration
    final flightDuration =
        (distance / 800 * 60).round(); // Assuming 800 km/h average speed

    // Total duration
    final totalDuration = busDuration +
        flightDuration +
        120; // Adding 2 hours for airport procedures

    // Format total time
    final hours = totalDuration ~/ 60;
    final minutes = totalDuration % 60;
    final durationText = '${hours}h ${minutes}min';

    // Create a mock polyline for the multi-modal path
    final multiModalPolyline =
        _createMockPolyline(origin.latLng, destination.latLng, 0.02);

    // Create a modified route object
    final modifiedRoute = {
      'legs': [
        {
          'duration': {'text': durationText},
          'distance': {
            'text': '${distance.toStringAsFixed(1)} km',
            'value': distance * 1000
          },
          'steps': []
        }
      ],
      'overview_polyline': {'points': multiModalPolyline}
    };

    // Add the multi-modal option with a special title
    _transitOptions.add(TransitOption(
      mode: TransitMode
          .bus, // Using bus as the primary mode, but we'll customize the display
      duration: durationText,
      distance: '${distance.toStringAsFixed(1)} km',
      price: _estimateMultiModalPrice(distance),
      isBest: false,
      steps: [],
      polyline: multiModalPolyline,
      origin: origin.name,
      destination: destination.name,
    ));

    // Add route polyline to map
    _routes.add(_createPolyline(
      'multimodal',
      _decodePolyline(multiModalPolyline),
      Colors.deepOrange,
    ));

    return true;
  }

  // Estimate price for multi-modal transport
  String _estimateMultiModalPrice(double distanceInKm) {
    // Base bus fare
    final busFare = 10;

    // Flight fare based on distance
    final minFlightFare = (50 + distanceInKm * 0.1).round();
    final maxFlightFare = (50 + distanceInKm * 0.15).round();

    return 'MYR${minFlightFare + busFare}-${maxFlightFare + busFare}';
  }

  Future<void> _fetchOptimizedRoute(List<TripLocation> locations) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.optimizedIntermediateWaypointIndex'
    };

    // Create waypoints from locations
    final intermediateWaypoints = locations
        .sublist(1, locations.length - 1)
        .map((loc) => {
              "location": {
                "latLng": {
                  "latitude": loc.latLng.latitude,
                  "longitude": loc.latLng.longitude
                }
              }
            })
        .toList();

    final body = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": locations.first.latLng.latitude,
            "longitude": locations.first.latLng.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": locations.last.latLng.latitude,
            "longitude": locations.last.latLng.longitude
          }
        }
      },
      "intermediates": intermediateWaypoints,
      "optimizeWaypointOrder": true,
      "travelMode": "DRIVE",
      "routingPreference": "TRAFFIC_AWARE",
      "computeAlternativeRoutes": false,
      "languageCode": "en-US",
      "units": "METRIC"
    });

    try {
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      // Handle response similar to other methods
    } catch (e) {
      print('Error fetching optimized route: $e');
    }
  }

  // Add this method to check if distance is long enough for flight
  bool _isLongDistance(TripLocation origin, TripLocation destination) {
    // Calculate straight-line distance
    final distance =
        _calculateStraightLineDistance(origin.latLng, destination.latLng);

    // If distance is greater than 500km, consider it long distance
    if (distance > 500) {
      return true;
    }

    // Check if locations are on different landmasses
    bool isOriginIsland = _isIslandLocation(origin.name);
    bool isDestinationIsland = _isIslandLocation(destination.name);

    // If one is on mainland and other is on island, or both on different islands
    if (isOriginIsland != isDestinationIsland ||
        (isOriginIsland &&
            isDestinationIsland &&
            !_areOnSameIsland(origin.name, destination.name))) {
      return true;
    }

    return false;
  }

  // Add method to sort and mark best options
  void _sortAndMarkBestOptions() {
    if (_transitOptions.isEmpty) return;

    // Reset all isBest flags
    for (var option in _transitOptions) {
      option.isBest = false;
    }

    // Sort by score (lower is better)
    _transitOptions.sort(
        (a, b) => _calculateRouteScore(a).compareTo(_calculateRouteScore(b)));

    // Mark the best option
    _transitOptions.first = _transitOptions.first.copyWith(isBest: true);

    print('Found ${_transitOptions.length} routes');
    for (var option in _transitOptions) {
      print(
          'Route: ${option.mode} - ${option.duration} - ${option.price} ${option.isBest ? '(BEST)' : ''}');
    }
  }

  // Add this method to handle location swapping
  void _swapLocations() async {
    try {
      setState(() {
        // Swap locations in the widget's list
        final temp = widget.locations[0];
        widget.locations[0] = widget.locations[1];
        widget.locations[1] = temp;

        // Clear existing routes and info
        _routes.clear();
        _routeInfo.clear();
        _isReversed = !_isReversed;
      });

      // Update markers with new order
      await _initializeMarkersAsync(reverse: _isReversed);

      // Fetch new routes for swapped locations
      await _fetchRoutes();

      // Update map bounds
      _fitMapBounds();

      // Update the database with new order
      if (_currentTripId != null) {
        await _firestore.collection('trips').doc(_currentTripId).update({
          'locations': widget.locations.map((loc) => loc.toMap()).toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      // Notify parent about the updated locations
      widget.onLocationsUpdated(widget.locations);
    } catch (e) {
      print('Error swapping locations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to swap locations')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _isMapExpanded
          ? null
          : AppBar(
              title: Text('My Trip'),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              leading: BackButton(color: Colors.black),
            ),
      body: WillPopScope(
        onWillPop: () async {
          if (_isMapExpanded) {
            setState(() {
              _isMapExpanded = false;
            });
            return false;
          }
          return true;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isMapExpanded)
              Expanded(
                child: Stack(
                  children: [
                    _buildMapSection(),
                    Positioned(
                      top: 40,
                      left: 16,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.arrow_back, color: Colors.black87),
                        onPressed: () {
                          setState(() {
                            _isMapExpanded = false;
                          });
                        },
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.fullscreen_exit,
                          color: Colors.black87,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMapExpanded = false;
                          });
                          Future.delayed(Duration(milliseconds: 300), () {
                            _fitMapBounds();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                child: Stack(
                  children: [
                    _buildMapSection(),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.fullscreen,
                          color: Colors.black87,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMapExpanded = true;
                          });
                          Future.delayed(Duration(milliseconds: 300), () {
                            _fitMapBounds();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isMapExpanded) ...[
              _buildLocationSwitcher(),
              _buildRouteTitle(),
              Expanded(
                child: _buildRouteOptions(),
              ),
              _buildAddDestination(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _fetchBusRoutes(
      TripLocation origin, TripLocation destination) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.transitDetails'
    };

    final body = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latLng.latitude,
            "longitude": origin.latLng.longitude
          }
        }
      },
      "destination": {
        "location": {
          "latLng": {
            "latitude": destination.latLng.latitude,
            "longitude": destination.latLng.longitude
          }
        }
      },
      "travelMode": "TRANSIT",
      "transitPreferences": {
        "allowedTravelModes": ["BUS"]
      },
      "computeAlternativeRoutes": true,
      "languageCode": "en-US",
      "units": "METRIC"
    });

    try {
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null) {
          for (var route in data['routes']) {
            _addTransitOption(
                route, TransitMode.bus, origin.name, destination.name,
                viaRoute: 'Bus');
          }
        }
      }
    } catch (e) {
      print('Error fetching bus routes: $e');
    }
  }

  Future<void> _fetchTrainToAirportOptions(
      TripLocation origin, TripLocation destination) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.transitDetails'
    };

    // First leg: Origin to nearest airport by train
    final body = jsonEncode({
      "origin": {
        "location": {
          "latLng": {
            "latitude": origin.latLng.latitude,
            "longitude": origin.latLng.longitude
          }
        }
      },
      "destination": {
        "placeId": "ChIJ5-rvAcdJzDERfSgkjrqz3A0" // KLIA airport place ID
      },
      "travelMode": "TRANSIT",
      "transitPreferences": {
        "allowedTravelModes": ["RAIL"]
      },
      "languageCode": "en-US",
      "units": "METRIC"
    });

    try {
      final response =
          await http.post(Uri.parse(url), headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          _addTransitOption(
              route, TransitMode.train, origin.name, destination.name,
              viaRoute: 'Train to KLIA, fly to Alor Setar');
        }
      }
    } catch (e) {
      print('Error fetching train to airport options: $e');
    }
  }
}

// Add this extension method
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
