import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const FirebaseOptions webOptions = FirebaseOptions(
    apiKey: 'AIzaSyDoefqSvF-XEjYwnOe3eoW6chB4Fq3-iZQ',  
    appId: '1:222067024871:android:33b4cec8a4530b806e1342',  
    messagingSenderId: '222067024871', 
    projectId: 'face-a68a0', // Project ID
    databaseURL: 'https://YOUR_PROJECT_ID_HERE.firebaseio.com',
    storageBucket: 'face-a68a0.firebasestorage.app',
  );

  static const FirebaseOptions windowsOptions = webOptions;
  static const FirebaseOptions linuxOptions = webOptions;
}
