import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_bottom_nav.dart';
import 'models/trip_location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'services/trip_state_manager.dart';

class TripPlanPage extends StatefulWidget {
  final String userEmail;
  final Map<String, dynamic>? initialPlace;

  const TripPlanPage({
    Key? key,
    required this.userEmail,
    this.initialPlace,
  }) : super(key: key);

  @override
  State<TripPlanPage> createState() => _TripPlanPageState();
}

class _TripPlanPageState extends State<TripPlanPage> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  List<TripLocation> _selectedLocations = [];
  Set<Polyline> _routes = {};
  Set<Marker> _markers = {};
  final String _placesApiKey = 'AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts';
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();
  List<TextEditingController> _locationControllers = [TextEditingController()];
  List<FocusNode> _locationFocusNodes = [FocusNode()];
  int _activeSearchIndex = -1;
  Map<int, List<dynamic>> _searchResultsMap = {};
  final TripStateManager _tripStateManager = TripStateManager();

  @override
  void initState() {
    super.initState();

    // First restore any existing locations
    _restoreLocations();

    // Then add new location if provided
    if (widget.initialPlace != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addInitialPlace();
      });
    }
  }

  void _setupLocationInput(int index) {
    _locationFocusNodes[index].addListener(() {
      if (_locationFocusNodes[index].hasFocus) {
        setState(() {
          _showSearchResults = true;
        });
      }
    });
  }

  Future<void> _searchPlaces(String query, int fieldIndex) async {
    if (query.isEmpty) {
      setState(() {
        _searchResultsMap[fieldIndex] = [];
        _showSearchResults = false;
        _activeSearchIndex = -1;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}'
            '&key=$_placesApiKey'
            '&components=country:my'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResultsMap[fieldIndex] = data['predictions'];
          _showSearchResults = data['predictions'].isNotEmpty;
          _activeSearchIndex = fieldIndex;
        });
      }
    } catch (e) {
      print('Error searching places: $e');
    }
  }

  Future<void> _selectPlace(String placeId, int index) async {
    try {
      final response = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/place/details/json'
            '?place_id=$placeId'
            '&fields=name,geometry,formatted_address'
            '&key=$_placesApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];

        final newLocation = TripLocation(
          placeId: placeId,
          name: result['name'],
          address: result['formatted_address'],
          latLng: LatLng(
            result['geometry']['location']['lat'],
            result['geometry']['location']['lng'],
          ),
        );

        setState(() {
          _showSearchResults = false;
          _activeSearchIndex = -1;

          // Add or update location
          if (index >= _selectedLocations.length) {
            _selectedLocations.add(newLocation);
            _tripStateManager.addLocation(newLocation);

            // Add a new empty field for the next location
            _locationControllers.add(TextEditingController());
            _locationFocusNodes.add(FocusNode());
            _setupLocationInput(_locationControllers.length - 1);
          } else {
            _selectedLocations[index] = newLocation;
            _tripStateManager.locations[index] = newLocation;
          }

          _updateMapMarkers();
          _updateRoutes();
        });
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  void _deleteLocation(int index) {
    setState(() {
      _selectedLocations.removeAt(index);
      _tripStateManager.removeLocation(index);
      _locationControllers.removeAt(index);
      _locationFocusNodes.removeAt(index);

      for (int i = index; i < _selectedLocations.length; i++) {
        _locationControllers[i].text = _selectedLocations[i].name;
      }

      if (_locationControllers.isEmpty) {
        _locationControllers.add(TextEditingController());
        _locationFocusNodes.add(FocusNode());
        _setupLocationInput(0);
      }

      _updateMapMarkers();
      _updateRoutes();
    });
  }

  void _handleTapOutside() {
    setState(() {
      _showSearchResults = false;
      _activeSearchIndex = -1;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    for (var controller in _locationControllers) {
      controller.dispose();
    }
    for (var node in _locationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTapOutside,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Trip',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(4.2105, 101.9758),
                              zoom: 6,
                            ),
                            markers: _markers,
                            polylines: _routes,
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Where do you want to go?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _locationControllers[0],
                                focusNode: _locationFocusNodes[0],
                                decoration: InputDecoration(
                                  hintText: 'Enter first location',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  suffixIcon: _locationControllers[0]
                                          .text
                                          .isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear),
                                          onPressed: () {
                                            setState(() {
                                              _locationControllers[0].clear();
                                              _showSearchResults = false;
                                              _searchResultsMap[0] = [];
                                            });
                                            if (_selectedLocations.isNotEmpty) {
                                              _deleteLocation(0);
                                            }
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) {
                                  if (value.trim().isEmpty) {
                                    setState(() {
                                      _searchResultsMap[0] = [];
                                      _showSearchResults = false;
                                      _activeSearchIndex = -1;
                                    });
                                  } else {
                                    _searchPlaces(value, 0);
                                  }
                                },
                                onTap: () {
                                  setState(() {
                                    _activeSearchIndex = 0;
                                    _showSearchResults =
                                        _locationControllers[0].text.isNotEmpty;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (_showSearchResults && _activeSearchIndex == 0)
                            _buildSearchResults(0),
                          ...List.generate(_selectedLocations.length, (index) {
                            final actualIndex = index + 1;
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller:
                                          _locationControllers[actualIndex],
                                      focusNode:
                                          _locationFocusNodes[actualIndex],
                                      decoration: InputDecoration(
                                        hintText: actualIndex ==
                                                _selectedLocations.length
                                            ? 'And then to?'
                                            : 'Enter next location',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        suffixIcon: _locationControllers[
                                                    actualIndex]
                                                .text
                                                .isNotEmpty
                                            ? IconButton(
                                                icon: Icon(Icons.clear),
                                                onPressed: () {
                                                  setState(() {
                                                    _locationControllers[
                                                            actualIndex]
                                                        .clear();
                                                    _showSearchResults = false;
                                                    _searchResultsMap[
                                                        actualIndex] = [];
                                                  });
                                                  _deleteLocation(actualIndex);
                                                },
                                              )
                                            : null,
                                      ),
                                      onChanged: (value) {
                                        if (value.trim().isEmpty) {
                                          setState(() {
                                            _searchResultsMap[actualIndex] = [];
                                            _showSearchResults = false;
                                            _activeSearchIndex = -1;
                                          });
                                        } else {
                                          _searchPlaces(value, actualIndex);
                                        }
                                      },
                                      onTap: () {
                                        setState(() {
                                          _activeSearchIndex = actualIndex;
                                          _showSearchResults =
                                              _locationControllers[actualIndex]
                                                  .text
                                                  .isNotEmpty;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                if (_showSearchResults &&
                                    _activeSearchIndex == actualIndex)
                                  _buildSearchResults(actualIndex),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: 3,
          userEmail: widget.userEmail,
        ),
      ),
    );
  }

  Widget _buildSearchResults(int fieldIndex) {
    final results = _searchResultsMap[fieldIndex] ?? [];
    if (results.isEmpty || _activeSearchIndex != fieldIndex) {
      return Container();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(vertical: 8),
      constraints: BoxConstraints(
        maxHeight: 200,
      ),
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
        physics: ClampingScrollPhysics(),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final place = results[index];
          return ListTile(
            title: Text(place['description']),
            onTap: () {
              _locationControllers[fieldIndex].text = place['description'];
              _selectPlace(place['place_id'], fieldIndex);
            },
          );
        },
      ),
    );
  }

  void _updateMapMarkers() {
    _markers.clear();
    for (var i = 0; i < _selectedLocations.length; i++) {
      final location = _selectedLocations[i];
      _markers.add(
        Marker(
          markerId: MarkerId(location.placeId),
          position: location.latLng,
          infoWindow: InfoWindow(title: location.name),
        ),
      );
    }
  }

  void _updateRoutes() {
    // TODO: Implement route updating using Google Directions API
  }

  void _restoreLocations() {
    setState(() {
      _selectedLocations = List.from(_tripStateManager.locations);

      // Always ensure at least one empty field
      _locationControllers = List.generate(
        _selectedLocations.length + 1,
        (index) {
          var controller = TextEditingController();
          if (index < _selectedLocations.length) {
            controller.text = _selectedLocations[index].name;
          }
          return controller;
        },
      );

      _locationFocusNodes = List.generate(
        _locationControllers.length,
        (index) => FocusNode(),
      );

      for (var i = 0; i < _locationControllers.length; i++) {
        _setupLocationInput(i);
      }

      _updateMapMarkers();
      _updateRoutes();
    });
  }

  Future<void> _addInitialPlace() async {
    final place = widget.initialPlace!;
    final placeId = place['place_id'];
    if (placeId != null) {
      // Get the next available index
      final index = _selectedLocations.length;

      // Ensure we have enough controllers and focus nodes
      while (_locationControllers.length <= index) {
        _locationControllers.add(TextEditingController());
        _locationFocusNodes.add(FocusNode());
        _setupLocationInput(_locationControllers.length - 1);
      }

      // Set the text and select the place
      _locationControllers[index].text = place['name'] ?? '';
      await _selectPlace(placeId, index);
    }
  }
}
