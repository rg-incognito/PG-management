import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class MessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    if (kDebugMode) {
      debugPrint('FCM token: $token');
    }
    return token;
  }
}
