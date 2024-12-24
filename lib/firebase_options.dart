import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyBiZiSSK_BCVqDA91Jtezygb5l1pz6JCm4',
      appId: '1:54586227246:android:436bd250b19e287e1ffdbf',
      messagingSenderId: '54586227246',
      projectId: 'timely-tourist',
      storageBucket: 'timely-tourist.firebasestorage.app',
    );
  }
}
