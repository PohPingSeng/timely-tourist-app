import 'package:flutter/material.dart';
import '../models/trip_location.dart';

class TripStateManager {
  static final TripStateManager _instance = TripStateManager._internal();
  factory TripStateManager() => _instance;
  TripStateManager._internal();

  List<TripLocation> locations = [];
  
  void addLocation(TripLocation location) {
    locations.add(location);
  }
  
  void removeLocation(int index) {
    if (index < locations.length) {
      locations.removeAt(index);
    }
  }
  
  void clearLocations() {
    locations.clear();
  }
} 