// Generated for GitHub-only workflow
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('DefaultFirebaseOptions have not been configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for iOS.');
      case TargetPlatform.macOS:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for macOS.');
      case TargetPlatform.windows:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for Windows.');
      case TargetPlatform.linux:
        throw UnsupportedError('DefaultFirebaseOptions have not been configured for Linux.');
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const android = {
    'apiKey': 'AIzaSyA...',
    'appId': '1:552455976634:android:6a19ef96331857c21f7483',
    'messagingSenderId': '552455976634',
    'projectId': 'p2p-webrtc-chat',
    'databaseURL': 'https://p2p-webrtc-chat-default-rtdb.europe-west1.firebasedatabase.app',
  };
}
