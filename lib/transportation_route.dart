import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'models/trip_location.dart';

class TransportationRoutePage extends StatefulWidget {
  final List<TripLocation> locations;
  final String userEmail;

  const TransportationRoutePage({
    Key? key,
    required this.locations,
    required this.userEmail,
  }) : super(key: key);

  @override
  _TransportationRoutePageState createState() =>
      _TransportationRoutePageState();
}

class _TransportationRoutePageState extends State<TransportationRoutePage> {
  final String _apiKey = 'AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts';
  GoogleMapController? _mapController;
  bool _isMapExpanded = false;
  Set<Marker> _markers = {};
  Set<Polyline> _routes = {};
  Map<String, dynamic> _routeInfo = {};
  bool _isLoading = true;
  bool _isReversed = false;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    if (widget.locations.length < 2) return;

    setState(() => _isLoading = true);

    try {
      final origin = _isReversed ? widget.locations[1] : widget.locations.first;
      final destination =
          _isReversed ? widget.locations.first : widget.locations[1];

      // Fetch driving route
      final drivingResponse = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latLng.latitude},${origin.latLng.longitude}'
          '&destination=${destination.latLng.latitude},${destination.latLng.longitude}'
          '&mode=driving'
          '&key=$_apiKey'));

      // Fetch walking route
      final walkingResponse = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latLng.latitude},${origin.latLng.longitude}'
          '&destination=${destination.latLng.latitude},${destination.latLng.longitude}'
          '&mode=walking'
          '&key=$_apiKey'));

      if (drivingResponse.statusCode == 200 &&
          walkingResponse.statusCode == 200) {
        final drivingData = json.decode(drivingResponse.body);
        final walkingData = json.decode(walkingResponse.body);

        setState(() {
          _routeInfo = {
            'driving': _extractRouteInfo(drivingData),
            'walking': _extractRouteInfo(walkingData),
          };

          // Add route polylines
          _routes.add(_createPolyline(
            'driving',
            _decodePolyline(
                drivingData['routes'][0]['overview_polyline']['points']),
            Colors.blue,
          ));
        });
      }
    } catch (e) {
      print('Error fetching routes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _extractRouteInfo(Map<String, dynamic> data) {
    final route = data['routes'][0]['legs'][0];
    return {
      'distance': route['distance']['text'],
      'duration': route['duration']['text'],
    };
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

  void _initializeMarkers() {
    setState(() {
      _markers.clear();
      for (var i = 0; i < widget.locations.length; i++) {
        final location = widget.locations[i];
        _markers.add(
          Marker(
            markerId: MarkerId(location.placeId),
            position: location.latLng,
            infoWindow: InfoWindow(
              title: location.name,
              snippet: 'Stop ${i + 1}',
            ),
          ),
        );
      }
    });
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
    return Container(
      height: _isMapExpanded ? MediaQuery.of(context).size.height : 200,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.locations.first.latLng,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              // Delay to ensure smooth animation
              Future.delayed(Duration(milliseconds: 300), () {
                _fitMapBounds();
              });
            },
            markers: _markers,
            polylines: _routes,
            myLocationEnabled: true,
            zoomControlsEnabled: _isMapExpanded,
            mapToolbarEnabled: _isMapExpanded,
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
                // Re-adjust map bounds after expanding/collapsing
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
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLocationChip(widget.locations.first, isFirst: true),
          IconButton(
            icon: Icon(Icons.swap_horiz),
            onPressed: () {
              setState(() {
                _isReversed = !_isReversed;
                // Refetch routes with reversed locations
                _fetchRoutes();
              });
            },
          ),
          _buildLocationChip(widget.locations[1], isFirst: false),
        ],
      ),
    );
  }

  Widget _buildLocationChip(TripLocation location, {required bool isFirst}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            location.name,
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(width: 4),
          Icon(Icons.close, size: 16),
        ],
      ),
    );
  }

  Widget _buildRouteTitle() {
    final destinationName =
        _isReversed ? widget.locations.first.name : widget.locations[1].name;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_routeInfo.length} ways to travel to $destinationName',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
            ),
      body: _isMapExpanded
          ? _buildMapSection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMapSection(),
                _buildLocationSwitcher(),
                _buildRouteTitle(),
                Expanded(
                  child: _buildRouteOptions(),
                ),
              ],
            ),
    );
  }

  Widget _buildRouteOptions() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        if (_routeInfo.containsKey('driving'))
          _buildRouteCard(
            icon: Icons.directions_car,
            mode: 'Drive',
            duration: _routeInfo['driving']['duration'],
            distance: _routeInfo['driving']['distance'],
            isBest: true,
          ),
        SizedBox(height: 8),
        if (_routeInfo.containsKey('walking'))
          _buildRouteCard(
            icon: Icons.directions_walk,
            mode: 'Walk',
            duration: _routeInfo['walking']['duration'],
            distance: _routeInfo['walking']['distance'],
            isBest: false,
          ),
        SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            // Handle add destination
          },
          icon: Icon(Icons.add),
          label: Text('Add Destination'),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard({
    required IconData icon,
    required String mode,
    required String duration,
    required String distance,
    required bool isBest,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () {
          // Handle route selection
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.black54),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$mode $distance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isBest) SizedBox(width: 8),
                        if (isBest)
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
                    ),
                    SizedBox(height: 4),
                    Text(
                      duration,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}
