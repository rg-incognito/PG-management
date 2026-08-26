import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Requests notification permission and exposes this device's FCM token,
/// used to alert staff when a tenant submits a payment claim.
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
