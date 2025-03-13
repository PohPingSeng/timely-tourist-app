import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';
import 'models/trip_location.dart';
import 'transportation_route.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'route_options_page.dart';
import 'tripPlan.dart';

class MultiTransportationRoutePage extends StatefulWidget {
  final List<TripLocation> locations;
  final String userEmail;
  final Function(TripLocation) onLocationRemoved;
  final Function(List<TripLocation>) onLocationsUpdated;

  const MultiTransportationRoutePage({
    super.key,
    required this.locations,
    required this.userEmail,
    required this.onLocationRemoved,
    required this.onLocationsUpdated,
  });

  @override
  _MultiTransportationRoutePageState createState() =>
      _MultiTransportationRoutePageState();
}

class _MultiTransportationRoutePageState
    extends State<MultiTransportationRoutePage> {
  final String _apiKey = 'AIzaSyD5fitoSIC-JDcKSTEOvnT0Yt-WF9NxvqQ';
  GoogleMapController? _mapController;
  bool _isMapExpanded = false;
  Set<Marker> _markers = {};
  Set<Polyline> _routes = {};
  List<TransitOption> _bestTransitOptions = [];
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initializeMarkersAsync().then((_) {
      _fetchAllRoutes();
    });
  }

  Future<void> _initializeMarkersAsync() async {
    final markers = <Marker>{};

    for (var i = 0; i < widget.locations.length; i++) {
      final location = widget.locations[i];
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
        style: const TextStyle(
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

  Future<void> _fetchAllRoutes() async {
    if (widget.locations.length < 2) return;

    _bestTransitOptions = [];
    _routes.clear();

    try {
      for (int i = 0; i < widget.locations.length - 1; i++) {
        final origin = widget.locations[i];
        final destination = widget.locations[i + 1];

        final response = await http.post(
          Uri.parse(
              'https://routes.googleapis.com/directions/v2:computeRoutes'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
          },
          body: jsonEncode({
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
            "routingPreference": "TRAFFIC_AWARE",
            "computeAlternativeRoutes": false,
            "languageCode": "en-US",
            "units": "METRIC"
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['routes']?.isNotEmpty) {
            final route = data['routes'][0];

            final option = TransitOption(
              mode: TransitMode.driving,
              duration: _formatDuration(
                  int.parse(route['duration'].replaceAll('s', ''))),
              distance: _formatDistance(route['distanceMeters']),
              price: _calculatePrice(route['distanceMeters']),
              isBest: true,
              steps: [],
              polyline: route['polyline']['encodedPolyline'],
              origin: origin.name,
              destination: destination.name,
            );

            setState(() {
              _bestTransitOptions.add(option);
              _addRouteToMap(option.polyline, option.mode);
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching routes: $e');
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes} min';
  }

  String _formatDistance(int meters) {
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _calculatePrice(int meters) {
    final km = meters / 1000;
    final price = 2 + (km * 0.70); // Base fare + per km rate
    return 'MYR${price.round()}';
  }

  void _addRouteToMap(String polyline, TransitMode mode) {
    final points = _decodePolyline(polyline);
    final route = _createPolyline(
      'route_${_routes.length}', // Unique ID for each route
      points,
      _getRouteColor(mode),
    );
    setState(() {
      _routes.add(route);
    });
  }

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

  Color _getRouteColor(TransitMode mode) {
    switch (mode) {
      case TransitMode.walking:
        return Colors.green;
      case TransitMode.cycling:
        return Colors.orange;
      case TransitMode.driving:
        return Colors.blue.shade600;
      case TransitMode.bus:
        return Colors.red;
      case TransitMode.train:
        return Colors.purple;
      case TransitMode.flight:
        return Colors.indigo;
      case TransitMode.ferry:
        return Colors.cyan;
      case TransitMode.motorcycle:
        return Colors.amber.shade700;
      default:
        return Colors.grey;
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

  void _showAllRoutesForSegment(int index) {
    if (index < 0 || index >= widget.locations.length - 1) return;

    final origin = widget.locations[index];
    final destination = widget.locations[index + 1];

    // Make sure we have a valid current route for this segment
    TransitOption? currentRoute;
    if (index < _bestTransitOptions.length) {
      currentRoute = _bestTransitOptions[index];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteOptionsPage(
          origin: origin,
          destination: destination,
          currentRoute: currentRoute,
          onRouteSelected: (selectedOption) {
            setState(() {
              // Make sure we have enough space in the list
              while (_bestTransitOptions.length <= index) {
                _bestTransitOptions.add(selectedOption);
              }
              // Update the selected route
              _bestTransitOptions[index] = selectedOption;
              // Refresh all routes on the map
              _routes.clear();
              for (var i = 0; i < _bestTransitOptions.length; i++) {
                _addRouteToMap(_bestTransitOptions[i].polyline,
                    _bestTransitOptions[i].mode);
              }
            });
          },
        ),
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
          zoomControlsEnabled: false, // Hide default zoom controls
          mapToolbarEnabled: false,
          zoomGesturesEnabled: true, // Enable pinch to zoom
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

  Future<void> _setMapStyle(GoogleMapController controller) async {
    String style = '''
      [
        {
          "featureType": "water",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#e9e9e9"
            }
          ]
        },
        {
          "featureType": "road",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#ffffff"
            }
          ]
        }
      ]
    ''';

    controller.setMapStyle(style);
  }

  Widget _buildRouteSegment(int index) {
    if (index >= _bestTransitOptions.length) return SizedBox.shrink();

    final option = _bestTransitOptions[index];
    final origin = widget.locations[index];
    final destination = widget.locations[index + 1];
    final color = _getRouteColor(option.mode);

    return InkWell(
      onTap: () => _showAllRoutesForSegment(index),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getModeIcon(option.mode),
                      color: color,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _getModeString(option.mode),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[900],
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              option.duration,
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          option.distance,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        option.price,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
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

  Widget _buildLocationItem(TripLocation location, int index) {
    return Dismissible(
      key: Key(location.placeId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20),
        color: Colors.red,
        child: Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        setState(() {
          final removedLocation = widget.locations[index];
          widget.locations.removeAt(index);
          widget.onLocationRemoved(removedLocation);
          widget.onLocationsUpdated(widget.locations);
          _initializeMarkersAsync().then((_) {
            _fetchAllRoutes();
          });
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Location',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to TripPlanPage
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TripPlanPage(
              userEmail: widget.userEmail,
            ),
          ),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _isMapExpanded
            ? null
            : AppBar(
                title: Text(
                  'My Trip',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                leading: BackButton(
                  color: Colors.black,
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TripPlanPage(
                          userEmail: widget.userEmail,
                        ),
                      ),
                      (route) => false,
                    );
                  },
                ),
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
              else ...[
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
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.locations.length,
                    itemBuilder: (context, index) {
                      final location = widget.locations[index];

                      // For all locations except the last one, show route info
                      if (index < widget.locations.length - 1) {
                        return Column(
                          children: [
                            _buildLocationItem(location, index),
                            _buildRouteSegment(index),
                          ],
                        );
                      }

                      // For the last location, just show the location
                      return _buildLocationItem(location, index);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
