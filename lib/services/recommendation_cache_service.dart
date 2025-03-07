import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RecommendationCacheService {
  static final RecommendationCacheService _instance = RecommendationCacheService._internal();
  factory RecommendationCacheService() => _instance;
  RecommendationCacheService._internal();

  static const String _cacheKey = 'cached_recommendations';
  static const Duration _cacheValidDuration = Duration(hours: 24);
  
  List<Map<String, dynamic>> _cachedRecommendations = [];
  DateTime? _lastFetchTime;

  Future<void> cacheRecommendations(List<Map<String, dynamic>> recommendations) async {
    _cachedRecommendations = recommendations;
    _lastFetchTime = DateTime.now();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode({
      'recommendations': recommendations,
      'timestamp': _lastFetchTime!.toIso8601String(),
    }));
  }

  Future<List<Map<String, dynamic>>> getCachedRecommendations() async {
    if (_cachedRecommendations.isNotEmpty) {
      return _cachedRecommendations;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    
    if (cached != null) {
      final data = jsonDecode(cached);
      _lastFetchTime = DateTime.parse(data['timestamp']);
      _cachedRecommendations = List<Map<String, dynamic>>.from(data['recommendations']);
    }
    
    return _cachedRecommendations;
  }

  bool get needsRefresh => _lastFetchTime == null || 
      DateTime.now().difference(_lastFetchTime!) > _cacheValidDuration;
} 