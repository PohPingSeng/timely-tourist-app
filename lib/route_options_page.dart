import 'package:flutter/material.dart';
import 'models/trip_location.dart';
import 'transportation_route.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteOptionsPage extends StatefulWidget {
  final TripLocation origin;
  final TripLocation destination;
  final TransitOption? currentRoute;
  final Function(TransitOption)? onRouteSelected;

  const RouteOptionsPage({
    Key? key,
    required this.origin,
    required this.destination,
    this.currentRoute,
    this.onRouteSelected,
  }) : super(key: key);

  @override
  _RouteOptionsPageState createState() => _RouteOptionsPageState();
}

class _RouteOptionsPageState extends State<RouteOptionsPage> {
  List<TransitOption> _transitOptions = [];
  final String _apiKey = 'AIzaSyD5fitoSIC-JDcKSTEOvnT0Yt-WF9NxvqQ';
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _routes = {};

  @override
  void initState() {
    super.initState();
    // Initialize markers
    _markers = {
      Marker(
        markerId: MarkerId('origin'),
        position: widget.origin.latLng,
        infoWindow: InfoWindow(title: widget.origin.name),
      ),
      Marker(
        markerId: MarkerId('destination'),
        position: widget.destination.latLng,
        infoWindow: InfoWindow(title: widget.destination.name),
      ),
    };
    _fetchRouteOptions();
  }

  Future<void> _fetchRouteOptions() async {
    if (widget.origin == null || widget.destination == null) return;

    _transitOptions.clear();

    try {
      final origin = widget.origin;
      final destination = widget.destination;

      print('Fetching routes from ${origin.name} to ${destination.name}');

      await Future.wait([
        _fetchWalkingDirections(origin, destination),
        _fetchDrivingDirections(origin, destination, preferHighways: true),
        _fetchDrivingDirections(origin, destination, preferHighways: false),
        _fetchMotorcycleDirections(origin, destination),
        _fetchPublicTransitRoutes(origin, destination),
        if (_isLongDistance(origin, destination))
          _fetchMultiModalOptions(origin, destination),
      ]);

      _sortAndMarkBestOptions();
    } catch (e) {
      print('Error fetching routes: $e');
    }
  }

  Future<void> _fetchWalkingDirections(
      TripLocation origin, TripLocation destination) async {
    final url = 'https://routes.googleapis.com/directions/v2:computeRoutes';

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs,routes.travelAdvisory,routes.walkingDetails'
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
      "travelMode": "WALK",
      "routingPreference": "WALK_SAFER",
      "computeAlternativeRoutes": true,
      "routeModifiers": {
        "avoidHighways": true,
        "avoidTolls": true,
        "avoidIndoor": false
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
            final distanceMeters =
                int.parse(route['distanceMeters'].toString());
            if (distanceMeters <= 3000) {
              bool isRouteSafe = true;
              if (route['travelAdvisory'] != null) {
                final warnings = route['travelAdvisory']['warnings'] as List?;
                isRouteSafe = warnings == null || warnings.isEmpty;
              }

              if (isRouteSafe) {
                _addTransitOption(
                    route, TransitMode.walking, origin.name, destination.name,
                    viaRoute: 'via pedestrian path');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching walking directions: $e');
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
            bool hasTolls = false;
            if (route['travelAdvisory'] != null) {
              final advisories =
                  route['travelAdvisory'] as Map<String, dynamic>;
              final hasTollRoads = advisories['tollRoads'] == true;
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

  void _addTransitOption(
    Map<String, dynamic> route,
    TransitMode mode,
    String origin,
    String destination, {
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

    final newOption = TransitOption(
      mode: mode,
      duration: durationText,
      distance: distanceText,
      price: 'Price varies',
      isBest: false,
      steps: route['legs'] ?? [],
      polyline: route['polyline']['encodedPolyline'],
      origin: origin,
      destination: destination,
      viaRoute: viaRoute,
      hasTolls: hasTolls,
      isMultiModal: isMultiModal,
    );

    setState(() {
      _transitOptions.add(newOption);
    });
  }

  Future<void> _fetchMultiModalOptions(
      TripLocation origin, TripLocation destination) async {
    // Implementation of _fetchMultiModalOptions method
  }

  void _sortAndMarkBestOptions() {
    if (_transitOptions.isEmpty) return;

    // Sort by duration
    _transitOptions.sort((a, b) =>
        _parseDuration(a.duration).compareTo(_parseDuration(b.duration)));

    // Reset all routes to not best
    for (var option in _transitOptions) {
      option.isBest = false;
    }

    // If there's a current route, mark only that one as best
    if (widget.currentRoute != null) {
      for (var option in _transitOptions) {
        if (option.mode == widget.currentRoute!.mode &&
            option.duration == widget.currentRoute!.duration &&
            option.distance == widget.currentRoute!.distance) {
          option.isBest = true;
          break; // Only mark one route as best
        }
      }
    }

    setState(() {});
  }

  // Helper method to parse duration string to minutes for sorting
  int _parseDuration(String duration) {
    final parts = duration.split(' ');
    int minutes = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].contains('h')) {
        minutes += int.parse(parts[i].replaceAll('h', '')) * 60;
      } else if (parts[i].contains('min')) {
        minutes += int.parse(parts[i].replaceAll('min', ''));
      }
    }

    return minutes;
  }

  Future<void> _fetchPublicTransitRoutes(
      TripLocation origin, TripLocation destination) async {
    // Implementation of _fetchPublicTransitRoutes method
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Plan',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Results',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Location info container
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${_transitOptions.length} ways to travel from ${widget.origin.name} to ${widget.destination.name}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),

          // Route options list
          Expanded(
            child: _transitOptions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.alt_route,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No routes available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _transitOptions.length,
                    itemBuilder: (context, index) {
                      final option = _transitOptions[index];
                      final color = _getModeColor(option.mode);

                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              // Update selection
                              setState(() {
                                for (var opt in _transitOptions) {
                                  opt.isBest = false;
                                }
                                option.isBest = true;
                              });

                              // Notify parent
                              if (widget.onRouteSelected != null) {
                                widget.onRouteSelected!(option);
                              }
                            },
                            child: Stack(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Selection indicator (plus or check)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _isCurrentRoute(option)
                                              ? color
                                              : Colors.grey[100],
                                        ),
                                        child: Icon(
                                          _isCurrentRoute(option)
                                              ? Icons.check
                                              : Icons.add,
                                          size: 16,
                                          color: _isCurrentRoute(option)
                                              ? Colors.white
                                              : Colors.grey[400],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      // Mode icon with colored background
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getModeIcon(option.mode),
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      // Route details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option.isMultiModal
                                                  ? option.viaRoute ??
                                                      _getModeString(
                                                          option.mode)
                                                  : _getModeString(option.mode),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey[900],
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  option.duration,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  ' · ${option.distance}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Price and arrow
                                      Row(
                                        children: [
                                          if (option.price.isNotEmpty)
                                            Text(
                                              option.price,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
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
                                // BEST label
                                if (index == 0)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomLeft: Radius.circular(8),
                                        ),
                                      ),
                                      child: Text(
                                        'BEST',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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

  // Add this method to calculate straight line distance
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

  // Add method to check if flight is needed
  bool _isLongDistance(TripLocation origin, TripLocation destination) {
    final distance =
        _calculateStraightLineDistance(origin.latLng, destination.latLng);
    return distance > 400; // Lower threshold to match transportation_route.dart
  }

  bool _isOnDifferentIslands(String origin, String destination) {
    // Implement island checking logic similar to TransportationRoutePage
    // ... (copy the island checking methods from TransportationRoutePage)
    return false;
  }

  // Add this method to get colors for different modes
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
        return Colors.grey;
    }
  }

  bool _isCurrentRoute(TransitOption option) {
    return option.isBest;
  }
}
