import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'models/trip_location.dart';
import 'dart:ui';
import 'dart:typed_data';

// Add new transit mode types
enum TransitMode { walking, cycling, driving, bus, train, flight, ferry }

class TransitOption {
  final TransitMode mode;
  final String duration;
  final String distance;
  final String price;
  final bool isBest;
  final List<dynamic> steps;
  final String polyline;

  TransitOption({
    required this.mode,
    required this.duration,
    required this.distance,
    required this.price,
    required this.isBest,
    required this.steps,
    required this.polyline,
  });
}

class TransportationRoutePage extends StatefulWidget {
  final List<TripLocation> locations;
  final String userEmail;
  final Function(TripLocation) onLocationRemoved;

  const TransportationRoutePage({
    super.key,
    required this.locations,
    required this.userEmail,
    required this.onLocationRemoved,
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

  @override
  void initState() {
    super.initState();
    _initializeMarkersAsync(reverse: _isReversed);
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    if (widget.locations.length < 2) return;

    setState(() => _isFetchingRoutes = true);
    _transitOptions.clear();
    _routes.clear();

    try {
      final origin = _isReversed ? widget.locations[1] : widget.locations.first;
      final destination =
          _isReversed ? widget.locations.first : widget.locations[1];

      // Calculate distance to determine suitable modes
      final distance =
          await _calculateDistance(origin.latLng, destination.latLng);
      final modes = _getApplicableModes(distance);

      // Fetch routes for each applicable mode
      for (var mode in modes) {
        final response = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${origin.latLng.latitude},${origin.latLng.longitude}'
            '&destination=${destination.latLng.latitude},${destination.latLng.longitude}'
            '&mode=${_getModeString(mode)}'
            '&alternatives=true'
            '&key=$_apiKey'));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes'].isNotEmpty) {
            _addTransitOption(data, mode);
          }
        }
      }

      // Sort options by duration and mark the fastest as best
      _transitOptions.sort((a, b) =>
          _parseDuration(a.duration).compareTo(_parseDuration(b.duration)));
      if (_transitOptions.isNotEmpty) {
        _transitOptions[0] = TransitOption(
          mode: _transitOptions[0].mode,
          duration: _transitOptions[0].duration,
          distance: _transitOptions[0].distance,
          price: _transitOptions[0].price,
          isBest: true,
          steps: _transitOptions[0].steps,
          polyline: _transitOptions[0].polyline,
        );
      }

      setState(() {});
    } catch (e) {
      print('Error fetching routes: $e');
    } finally {
      setState(() => _isFetchingRoutes = false);
    }
  }

  List<TransitMode> _getApplicableModes(double distanceInKm) {
    if (distanceInKm <= 5) {
      return [TransitMode.walking, TransitMode.cycling, TransitMode.driving];
    } else if (distanceInKm <= 300) {
      return [TransitMode.driving, TransitMode.bus, TransitMode.train];
    } else {
      return [TransitMode.flight, TransitMode.train];
    }
  }

  void _addTransitOption(Map<String, dynamic> data, TransitMode mode) {
    final route = data['routes'][0]['legs'][0];
    final steps = route['steps'];
    final polyline = data['routes'][0]['overview_polyline']['points'];

    _transitOptions.add(TransitOption(
      mode: mode,
      duration: route['duration']['text'],
      distance: route['distance']['text'],
      price: _estimatePrice(
          mode, double.parse(route['distance']['value'].toString())),
      isBest: false,
      steps: steps,
      polyline: polyline,
    ));

    // Add route polyline to map
    _routes.add(_createPolyline(
      mode.toString(),
      _decodePolyline(polyline),
      _getModeColor(mode),
    ));
  }

  String _estimatePrice(TransitMode mode, double distanceInMeters) {
    // Implement price estimation logic based on mode and distance
    // This is a simplified example
    switch (mode) {
      case TransitMode.walking:
      case TransitMode.cycling:
        return 'Free';
      case TransitMode.driving:
        return 'RM ${(distanceInMeters * 0.0005).toStringAsFixed(2)}';
      case TransitMode.bus:
        return 'RM ${(distanceInMeters * 0.0002).toStringAsFixed(2)}';
      case TransitMode.train:
        return 'RM ${(distanceInMeters * 0.0003).toStringAsFixed(2)}';
      default:
        return 'Price varies';
    }
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
    return Expanded(
      child: Stack(
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
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              child: Icon(
                _isMapExpanded ? Icons.close : Icons.fullscreen,
                color: Colors.black87,
              ),
              onPressed: () {
                setState(() {
                  _isMapExpanded = !_isMapExpanded;
                });
                Future.delayed(Duration(milliseconds: 300), () {
                  _fitMapBounds();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSwitcher() {
    final firstLocation =
        _isReversed ? widget.locations[1] : widget.locations.first;
    final secondLocation =
        _isReversed ? widget.locations.first : widget.locations[1];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      firstLocation.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      widget.onLocationRemoved(firstLocation);
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: () async {
              setState(() {
                _isReversed = !_isReversed;
                _routes.clear();
                _routeInfo.clear();
              });
              await _initializeMarkersAsync(reverse: _isReversed);
              await _fetchRoutes();
              _fitMapBounds();
            },
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      secondLocation.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      widget.onLocationRemoved(secondLocation);
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTitle() {
    final destinationName =
        _isReversed ? widget.locations.first.name : widget.locations[1].name;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        '${_routeInfo.length} ways to travel to $destinationName',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
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
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            // Handle route selection
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.black54, size: 20),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$mode $distance',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          if (isBest) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'BEST',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            duration,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            price,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.black54),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding the best routes...'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _transitOptions.length,
      itemBuilder: (context, index) {
        final option = _transitOptions[index];
        return _buildRouteCard(
          icon: _getModeIcon(option.mode),
          mode: _getModeString(option.mode),
          duration: option.duration,
          distance: option.distance,
          price: option.price,
          isBest: option.isBest,
        );
      },
    );
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
          onTap: () {
            _showAddDestinationSearch();
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

  void _showAddDestinationSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                      onChanged: (query) {
                        // Implement place search with autocomplete
                        // Similar to TripPlan's search functionality
                      },
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),
            Expanded(
              child: ListView(
                // Show search results here
                children: [],
              ),
            ),
          ],
        ),
      ),
    );
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
    final lat2 = destination.latitude * pi / 180;
    final dLat = (destination.latitude - origin.latitude) * pi / 180;
    final dLon = (destination.longitude - origin.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
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
                  ],
                ),
              )
            else
              Container(
                height: 200,
                child: _buildMapSection(),
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
}
