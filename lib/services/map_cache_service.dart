import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MapCacheService {
  static final MapCacheService _instance = MapCacheService._internal();
  factory MapCacheService() => _instance;
  MapCacheService._internal();

  static const String _lastPositionKey = 'last_map_position';
  static const String _lastZoomKey = 'last_map_zoom';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  CameraPosition? _cachedPosition;
  DateTime? _lastUpdateTime;
  Set<Marker> _cachedMarkers = {};

  Future<void> cacheMapState(
      CameraPosition position, Set<Marker> markers) async {
    _cachedPosition = position;
    _cachedMarkers = markers;
    _lastUpdateTime = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastPositionKey,
        json.encode({
          'lat': position.target.latitude,
          'lng': position.target.longitude,
          'timestamp': _lastUpdateTime!.toIso8601String(),
        }));
    await prefs.setDouble(_lastZoomKey, position.zoom);
  }

  Future<CameraPosition> getInitialPosition() async {
    if (_cachedPosition != null) {
      return _cachedPosition!;
    }

    final prefs = await SharedPreferences.getInstance();
    final positionJson = prefs.getString(_lastPositionKey);
    final zoom = prefs.getDouble(_lastZoomKey) ?? 6.0;

    if (positionJson != null) {
      final data = json.decode(positionJson);
      return CameraPosition(
        target: LatLng(data['lat'], data['lng']),
        zoom: zoom,
      );
    }

    // Default position (Malaysia)
    return CameraPosition(
      target: LatLng(4.2105, 101.9758),
      zoom: 6,
    );
  }

  Set<Marker> getCachedMarkers() => _cachedMarkers;

  bool shouldUpdatePosition(LatLng newPosition) {
    if (_cachedPosition == null) return true;

    // Update if moved more than 100 meters
    const minDistanceChange = 0.1; // approximately 100 meters
    final latDiff =
        (newPosition.latitude - _cachedPosition!.target.latitude).abs();
    final lngDiff =
        (newPosition.longitude - _cachedPosition!.target.longitude).abs();

    return latDiff > minDistanceChange || lngDiff > minDistanceChange;
  }

  bool get needsRefresh =>
      _lastUpdateTime == null ||
      DateTime.now().difference(_lastUpdateTime!) > _cacheValidDuration;
}
