import 'session_manager.dart';

Future<void> logout() async {
  try {
    SessionManager().clearSession();
    // Your existing logout logic
  } catch (e) {
    print('Error during logout: $e');
    throw e;
  }
} 