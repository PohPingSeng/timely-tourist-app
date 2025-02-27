import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'widgets/custom_bottom_nav.dart';

class MapPage extends StatefulWidget {
  final String userEmail;

  const MapPage({Key? key, required this.userEmail}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _controller;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  double _currentZoom = 15.0;
  late StreamSubscription<Position> _positionStreamSubscription;
  List<dynamic> _searchResults = [];
  Set<String> _searchHistory = {};
  MapType _currentMapType = MapType.normal;
  bool _showSearchResults = false;
  Set<Polygon> _polygons = {};

  // Add your places API key here
  final String _placesApiKey = 'AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts';

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Add this FocusNode as a class variable
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkPermissionAndGetLocation();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied');
          return;
        }
      }

      // Start real-time location tracking
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best, // Highest accuracy
        distanceFilter: 5, // Update every 5 meters
        timeLimit: null, // No time limit
      );

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        print('New position: ${position.latitude}, ${position.longitude}');
        setState(() {
          _currentPosition = position;
          _updateMarker(position);
        });

        _controller?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: _currentZoom,
            ),
          ),
        );
      });
    } catch (e) {
      print('Error in location tracking: $e');
    }
  }

  void _updateMarker(Position position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: MarkerId('currentLocation'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: InfoWindow(
          title: 'Your Location',
          snippet: '${position.latitude}, ${position.longitude}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _updateMapStyle();
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: _currentZoom,
          ),
        ),
      );
    }
  }

  void _zoomIn() {
    _currentZoom = _currentZoom + 1;
    _controller?.animateCamera(CameraUpdate.zoomTo(_currentZoom));
  }

  void _zoomOut() {
    _currentZoom = _currentZoom - 1;
    _controller?.animateCamera(CameraUpdate.zoomTo(_currentZoom));
  }

  void _centerToCurrentLocation() {
    if (_currentPosition != null) {
      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: _currentZoom,
          ),
        ),
      );
    }
  }

  // Add search places function
  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=$query'
            '&key=$_placesApiKey'
            '&components=country:my'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['predictions'];
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    }
  }

  // Add function to get place details and move camera
  Future<void> _selectPlace(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&fields=name,type,geometry,address_components'
            '&key=$_placesApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final types = data['result']['types'];
        final name = data['result']['name'];
        final geometry = data['result']['geometry'];

        // Reset previous state
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
          _markers.removeWhere((m) => m.markerId.value != 'currentLocation');
        });

        // For states and districts, show boundaries
        if (types.contains('administrative_area_level_1') ||
            types.contains('administrative_area_level_2')) {
          // Reset map style first
          await _controller?.setMapStyle(null);

          // Move camera to show the entire area
          if (geometry['viewport'] != null) {
            await _controller?.animateCamera(
              CameraUpdate.newLatLngBounds(
                LatLngBounds(
                  southwest: LatLng(
                    geometry['viewport']['southwest']['lat'],
                    geometry['viewport']['southwest']['lng'],
                  ),
                  northeast: LatLng(
                    geometry['viewport']['northeast']['lat'],
                    geometry['viewport']['northeast']['lng'],
                  ),
                ),
                50,
              ),
            );
          }
        } else {
          // For specific locations (not states/districts), show marker
          await _controller?.setMapStyle(null);

          if (geometry['location'] != null) {
            setState(() {
              _markers.add(
                Marker(
                  markerId: MarkerId(placeId),
                  position: LatLng(
                    geometry['location']['lat'],
                    geometry['location']['lng'],
                  ),
                  infoWindow: InfoWindow(title: name),
                ),
              );
            });

            // Move camera to the marker
            await _controller?.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(
                    geometry['location']['lat'],
                    geometry['location']['lng'],
                  ),
                  zoom: 15,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  // Add this function to save search history
  void _addToSearchHistory(String place) {
    setState(() {
      // Remove if exists and add to beginning
      _searchHistory.remove(place);
      _searchHistory = {place, ..._searchHistory};
    });
  }

  // Add this function to remove from search history
  void _removeFromHistory(String place) {
    setState(() {
      _searchHistory.remove(place);
    });
  }

  // Add this function to update map style
  void _updateMapStyle() async {
    if (_controller == null) return;

    if (_currentMapType == MapType.normal) {
      await _controller!.setMapStyle(null);
    } else {
      // Enhanced style for satellite view with visible POIs and labels
      String style = '''[
        {
          "elementType": "labels",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "administrative",
          "elementType": "geometry",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "poi",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "road",
          "elementType": "labels",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "road",
          "elementType": "geometry",
          "stylers": [
            {
              "color": "#ffffff",
              "weight": 1
            }
          ]
        },
        {
          "featureType": "transit",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        },
        {
          "featureType": "landscape",
          "elementType": "labels",
          "stylers": [
            {
              "visibility": "on"
            }
          ]
        }
      ]''';
      await _controller!.setMapStyle(style);
    }
  }

  // Add this function to create dashed pattern
  List<LatLng> _createDashedLine(LatLng start, LatLng end, int dashCount) {
    List<LatLng> points = [];
    double latStep = (end.latitude - start.latitude) / (dashCount * 2);
    double lngStep = (end.longitude - start.longitude) / (dashCount * 2);

    for (int i = 0; i < dashCount * 2; i += 2) {
      points.add(LatLng(
        start.latitude + (latStep * i),
        start.longitude + (lngStep * i),
      ));
      points.add(LatLng(
        start.latitude + (latStep * (i + 1)),
        start.longitude + (lngStep * (i + 1)),
      ));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with GestureDetector
          GestureDetector(
            onTap: () {
              print("Map tapped");
              _searchFocusNode.unfocus();
              setState(() {
                _showSearchResults = false;
              });
            },
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(0, 0),
                zoom: _currentZoom,
              ),
              onMapCreated: _onMapCreated,
              markers: _markers,
              polygons: _polygons,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: _currentMapType,
              compassEnabled: true,
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
              },
              onTap: (_) {
                _searchFocusNode.unfocus();
                setState(() {
                  _showSearchResults = false;
                });
              },
            ),
          ),

          // Search Bar with Results
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                // Search Bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onTap: () {
                      setState(() {
                        _showSearchResults = true;
                      });
                    },
                    // Enable text editing
                    enableInteractiveSelection: true,
                    // Allow backspace and deletion
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search Places',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showSearchResults = false;
                                });
                                // Clear markers and reset map style
                                _markers.removeWhere((m) =>
                                    m.markerId.value != 'currentLocation');
                                _controller?.setMapStyle(null);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          _searchResults = _searchHistory.isNotEmpty
                              ? _searchHistory.toList()
                              : [];
                        });
                      } else {
                        _searchPlaces(value);
                      }
                    },
                  ),
                ),

                // Search Results
                if (_showSearchResults &&
                    (_searchResults.isNotEmpty ||
                        (_searchController.text.isEmpty &&
                            _searchHistory.isNotEmpty)))
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchController.text.isEmpty
                          ? _searchHistory.length
                          : _searchResults.length,
                      itemBuilder: (context, index) {
                        if (_searchController.text.isEmpty) {
                          final place = _searchHistory.elementAt(index);
                          return ListTile(
                            title: Text(place),
                            trailing: IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => _removeFromHistory(place),
                            ),
                            onTap: () async {
                              setState(() {
                                _searchController.text = place;
                                _showSearchResults = false;
                              });

                              final response = await http.get(
                                Uri.parse(
                                    'https://maps.googleapis.com/maps/api/place/findplacefromtext/json'
                                    '?input=$place'
                                    '&inputtype=textquery'
                                    '&key=$_placesApiKey'),
                              );

                              if (response.statusCode == 200) {
                                final data = json.decode(response.body);
                                if (data['candidates'].isNotEmpty) {
                                  final placeId =
                                      data['candidates'][0]['place_id'];
                                  _selectPlace(placeId);
                                }
                              }
                            },
                          );
                        } else {
                          final place = _searchResults[index];
                          return ListTile(
                            title: Text(place['description']),
                            onTap: () {
                              setState(() {
                                _searchController.text = place['description'];
                                _showSearchResults = false;
                              });
                              _addToSearchHistory(place['description']);
                              _selectPlace(place['place_id']);
                              FocusScope.of(context).unfocus();
                            },
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: "zoomIn",
                  backgroundColor: Colors.white,
                  child: Icon(Icons.add, color: Colors.black87),
                  onPressed: _zoomIn,
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: "zoomOut",
                  backgroundColor: Colors.white,
                  child: Icon(Icons.remove, color: Colors.black87),
                  onPressed: _zoomOut,
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: "mapType",
                  backgroundColor: Colors.white,
                  child: Icon(
                    _currentMapType == MapType.normal
                        ? Icons.satellite_alt
                        : Icons.map,
                    color: Colors.black87,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal
                          ? MapType.hybrid
                          : MapType.normal;
                    });
                    _updateMapStyle();
                  },
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: "myLocation",
                  backgroundColor: Colors.white,
                  child: Icon(Icons.my_location, color: Colors.black87),
                  onPressed: _centerToCurrentLocation,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2,
        userEmail: widget.userEmail,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _positionStreamSubscription.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
