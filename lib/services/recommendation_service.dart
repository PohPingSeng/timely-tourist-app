// ignore_for_file: unused_import
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:google_maps_webservice/places.dart' as places;
import 'firestore_service.dart';
import 'dart:async';

class RecommendationService {
  final FirestoreService _firestoreService = FirestoreService();
  final places.GoogleMapsPlaces placesApi = places.GoogleMapsPlaces(
      apiKey: 'AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts');
  late IO.Socket socket;

  RecommendationService() {
    print('🔵 DEBUG: Initializing RecommendationService');

    socket = IO.io('http://10.0.2.2:9999', <String, dynamic>{
      // Use 10.0.2.2 for Android emulator
      'transports': ['websocket', 'polling'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
      'timeout': 20000,
    });

    socket.onConnect((_) {
      print('✅ DEBUG: Socket Connected successfully');
    });

    socket.onConnectError((error) {
      print('❌ DEBUG: Socket Connect Error: $error');
      print('❗ Make sure Python backend is running on port 9999');
    });
    socket.onError((error) => print('DEBUG: Socket Error: $error'));
    socket.onDisconnect((_) => print('DEBUG: Socket Disconnected'));

    print('🔄 DEBUG: Attempting socket connection...');
    socket.connect();
  }

  Future<List<Map<String, dynamic>>> getRecommendations(
      String userEmail) async {
    print('DEBUG: Starting getRecommendations for $userEmail');
    try {
      // Get user preferences from Firestore
      final userData = await _firestoreService.getUserData(userEmail);
      print('DEBUG: Firestore data: $userData');
      if (userData == null) return [];

      // Extract user preferences
      final preferences = {
        'personality_traits': userData['personalityTraits']?.toLowerCase(),
        'tourism_category': userData['tourismCategory']?.toLowerCase(),
        'travel_motivation': userData['travelMotivation']?.toLowerCase(),
        'travelling_concerns': userData['travellingConcerns']?.toLowerCase(),
      };
      print('DEBUG: Extracted preferences: $preferences'); // Debug log

      // Get recommendations from Python backend
      final recommendations = await _getRecommendationsFromEngine(preferences);
      print('DEBUG: Engine recommendations: $recommendations'); // Debug log

      // Enrich recommendations with place details
      final enriched = await _enrichWithPlaceDetails(recommendations);
      print('DEBUG: Enriched recommendations: $enriched'); // Debug log
      return enriched;
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getRecommendationsFromEngine(
      Map<String, dynamic> preferences) {
    final completer = Completer<List<Map<String, dynamic>>>();

    print('DEBUG: Sending to engine: $preferences'); // Debug log
    socket.emitWithAck('get_recommendations', preferences, ack: (response) {
      print('DEBUG: Engine response: $response'); // Debug log
      try {
        if (response == null) {
          completer.completeError('Null response from engine');
          return;
        }

        // Fix the response format handling
        if (response is List) {
          // Server is returning a direct list of recommendations
          completer.complete(List<Map<String, dynamic>>.from(response));
        } else if (response is Map && response['recommendations'] != null) {
          // Server is returning {recommendations: [...]}
          completer.complete(
              List<Map<String, dynamic>>.from(response['recommendations']));
        } else if (response['error'] != null) {
          completer.completeError(response['error']);
        } else {
          completer.completeError('Invalid response format from engine');
        }
      } catch (e) {
        print('DEBUG: Error processing engine response: $e');
        completer.completeError('Error processing engine response: $e');
      }
    });

    // Add timeout
    Future.delayed(Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        print('DEBUG: Engine timeout'); // Debug log
        completer.completeError('Recommendation engine timeout');
      }
    });

    return completer.future;
  }

  Future<List<Map<String, dynamic>>> _enrichWithPlaceDetails(
      List<Map<String, dynamic>> recommendations) async {
    List<Map<String, dynamic>> enrichedRecommendations = [];

    for (var rec in recommendations) {
      try {
        final response = await placesApi.searchByText(rec['location']);
        if (response.results.isNotEmpty) {
          final place = response.results.first;
          enrichedRecommendations.add({
            ...rec,
            'image': place.photos.isNotEmpty
                ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${place.photos.first.photoReference}&key=AIzaSyAzPTuVu8DrzsaDi_fNpdGMwdNFByeq2ts'
                : null,
            'rating': place.rating,
            'location': place.formattedAddress,
            'opening_hours': place.openingHours?.periods,
            'is_open': place.openingHours?.openNow,
          });
        }
      } catch (e) {
        print('Error enriching place details: $e');
      }
    }

    return enrichedRecommendations;
  }
}
